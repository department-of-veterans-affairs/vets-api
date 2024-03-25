# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'
require 'lighthouse/benefits_documents/form526/documents_status_polling_service'

RSpec.describe BenefitsDocuments::Form526::UpdateDocumentsStatusService do
  describe '#call' do
    let(:pending_document_upload) do
      create(:lighthouse526_document_upload, document_type: 'BDD Instructions', aasm_state: 'pending')
    end

    context 'when a Lighthouse526DocumentUpload has completed all steps in Lighthouse' do
      let(:lighthouse_completed_document_status) do
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => pending_document_upload.lighthouse_document_request_id,
                'status' => 'SUCCESS',
                'time' => {
                  'startTime' => 499152030,
                  'endTime' => 499152060
                },
                'steps' => [
                  {
                    'name' => 'CLAIMS_EVIDENCE',
                    'status' => 'SUCCESS'
                  },
                  {
                    'name' => 'BENEFITS_GATEWAY_SERVICE',
                    'status' => 'SUCCESS'
                  }
                ]
              }
            ]
          }
        }
      end

      it 'transitions that document to the complete state' do
        uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)
        described_class.call(uploads, lighthouse_completed_document_status)

        expect(pending_document_upload.reload.aasm_state).to eq('completed')
      end

      it 'logs the document completion to DataDog' do
        uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)
        expect { described_class.call(uploads, lighthouse_completed_document_status) }.to trigger_statsd_increment(
          'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
        )
      end
    end

    context 'when a Lighthouse526DocumentUpload fails in Lighthouse processing' do
      let(:lighthouse_failed_document_status) do
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => pending_document_upload.lighthouse_document_request_id,
                'status' => 'FAILED',
                'time' => {
                  'startTime' => 499152030,
                  'endTime' => 499152060
                },
                'steps' => [
                  {
                    'name' => 'CLAIMS_EVIDENCE',
                    'status' => 'FAILED'
                  },
                  {
                    'name' => 'BENEFITS_GATEWAY_SERVICE',
                    'status' => 'NOT_STARTED'
                  }
                ],
                'error' => {
                  'detail' => 'VBMS System Outage',
                  'step' => 'CLAIMS_EVIDENCE'
                }
              }
            ]
          }
        }
      end

      it 'transitions the document to the failed state' do
        uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)
        described_class.call(uploads, lighthouse_failed_document_status)

        expect(pending_document_upload.reload.aasm_state).to eq('failed')
      end

      it 'logs the document failure to DataDog' do
        uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)
        expect { described_class.call(uploads, lighthouse_failed_document_status) }.to trigger_statsd_increment(
          'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.failed.claims_evidence'
        )
      end
    end

    context 'when the document is still in progress at Lighthouse' do
      let(:lighthouse_processing_start_time) { DateTime.new(1985, 10, 26) }
      let(:lighthouse_in_progress_document_status) do
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => pending_document_upload.lighthouse_document_request_id,
                'status' => 'IN_PROGRESS',
                'time' => {
                  'startTime' => lighthouse_processing_start_time.to_time.to_i,
                  'endTime' => nil
                },
                'steps' => [
                  {
                    'name' => 'CLAIMS_EVIDENCE',
                    'status' => 'IN_PROGRESS'
                  },
                  {
                    'name' => 'BENEFITS_GATEWAY_SERVICE',
                    'status' => 'NOT_STARTED'
                  }
                ]
              }
            ]
          }
        }
      end

      context 'when it has been more than 24 hours since Lighthouse started processing the document' do
        it 'logs a processing timeout metric to statsd' do
          Timecop.freeze(lighthouse_processing_start_time + 2.days) do
            uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)

            expect { described_class.call(uploads, lighthouse_in_progress_document_status) }.to trigger_statsd_increment(
              'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.processing_timeout'
            )
          end
        end
      end

      context 'when it has been less than 24 hours since Lighthouse started processing the document' do
        it 'does not log a processing timeout metric to statsd' do
          Timecop.freeze(lighthouse_processing_start_time + 2.hours) do
            uploads = Lighthouse526DocumentUpload.where(id: pending_document_upload.id)

            expect { described_class.call(uploads, lighthouse_in_progress_document_status) }.not_to trigger_statsd_increment(
              'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.processing_timeout'
            )
          end
        end
      end
    end

    describe 'document type in statsd metrics' do
      # Helper method, responses will be the same just with different document request ids
      def mock_success_response(request_id)
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => request_id,
                'status' => 'SUCCESS',
                'time' => {
                  'startTime' => 499152030,
                  'endTime' => 499152060
                }
              }
            ]
          }
        }
      end

      before do
        # Stub update behavior; we are just testing metrics keys include the correct document type
        allow_any_instance_of(BenefitsDocuments::Form526::UploadStatusUpdater).to receive(:update_status)
        allow_any_instance_of(Lighthouse526DocumentUpload).to receive(:completed?).and_return(true)
      end

      context 'When the document is BDD Instructions' do
        let(:bdd_instruction_upload) { create(:lighthouse526_document_upload, document_type: 'BDD Instructions') }

        it 'increments the correct statsd metric' do
          uploads = Lighthouse526DocumentUpload.where(id: bdd_instruction_upload.id)
          status_response = mock_success_response(bdd_instruction_upload.lighthouse_document_request_id)

          expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
          )
        end
      end

      context 'When the document is a Form 0781' do
        let(:form_0781_upload) { create(:lighthouse526_document_upload, document_type: 'Form 0781') }

        it 'increments the correct statsd metric' do
          uploads = Lighthouse526DocumentUpload.where(id: form_0781_upload.id)
          status_response = mock_success_response(form_0781_upload.lighthouse_document_request_id)

          expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.form_0781.complete'
          )
        end
      end

      context 'When the document is a Form 0781a' do
        let(:form_0781a_upload) { create(:lighthouse526_document_upload, document_type: 'Form 0781a') }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
            mock_success_response(form_0781a_upload.lighthouse_document_request_id)
          )
        end

        it 'increments the correct statsd metric' do
          uploads = Lighthouse526DocumentUpload.where(id: form_0781a_upload.id)
          status_response = mock_success_response(form_0781a_upload.lighthouse_document_request_id)

          expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.form_0781a.complete'
          )
        end
      end

      context 'When the document is a Veteran Upload' do
        let(:veteran_upload) { create(:lighthouse526_document_upload, document_type: 'Veteran Upload') }

        it 'increments the correct statsd metric' do
          uploads = Lighthouse526DocumentUpload.where(id: veteran_upload.id)
          status_response = mock_success_response(veteran_upload.lighthouse_document_request_id)

          expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.veteran_upload.complete'
          )
        end
      end
    end
  end
end
