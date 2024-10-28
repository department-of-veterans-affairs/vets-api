# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'
require 'lighthouse/benefits_documents/form526/documents_status_polling_service'

RSpec.describe BenefitsDocuments::Form526::UpdateDocumentsStatusService do
  let(:start_time) { Time.new(1985, 10, 26).utc }

  # NOTE: The Lighthouse Benefits Documents API returns UNIX timestamps in milliseconds
  let(:start_time_in_unix_milliseconds) { start_time.to_i * 1000 }

  # Simulate Lighthouse processing time offset
  let(:end_time_in_unix_milliseconds) { (start_time + 30.seconds).to_i * 1000 }

  describe '#call' do
    let(:pending_document_upload) { create(:lighthouse526_document_upload, document_type: 'Veteran Upload') }
    let(:uploads) { Lighthouse526DocumentUpload.where(id: pending_document_upload.id) }
    let(:status_response) do
      {
        'data' => {
          'statuses' => [
            {
              'requestId' => pending_document_upload.lighthouse_document_request_id,
              'status' => status,
              'time' => { 'startTime' => start_time_in_unix_milliseconds, 'endTime' => end_time },
              'steps' => steps,
              'error' => error
            }
          ]
        }
      }
    end

    shared_examples 'document status updater' do |expected_state, metrics_key|
      it "transitions the document to #{expected_state}" do
        described_class.call(uploads, status_response)
        expect(pending_document_upload.reload.aasm_state).to eq(expected_state)
      end

      it "logs the #{expected_state} document to DataDog" do
        expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(metrics_key)
      end
    end

    context 'when a Lighthouse526DocumentUpload has completed all steps in Lighthouse' do
      let(:status) { 'SUCCESS' }
      let(:steps) do
        [
          { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'SUCCESS' },
          { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'SUCCESS' }
        ]
      end
      let(:error) { nil }
      let(:end_time) { end_time_in_unix_milliseconds }

      it_behaves_like 'document status updater', 'completed',
                      'api.form526.lighthouse_document_upload_processing_status.veteran_upload.complete'
    end

    context 'when a Lighthouse526DocumentUpload fails in Lighthouse processing' do
      let(:status) { 'FAILED' }
      let(:steps) do
        [
          { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'FAILED' },
          { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
        ]
      end
      let(:error) { { 'detail' => 'VBMS System Outage', 'step' => 'CLAIMS_EVIDENCE' } }
      let(:end_time) { end_time_in_unix_milliseconds }

      it_behaves_like 'document status updater', 'failed',
                      'api.form526.lighthouse_document_upload_processing_status.veteran_upload.failed.claims_evidence'
    end

    context 'when a Lighthouse526DocumentUpload is still in progress at Lighthouse' do
      let(:status) { 'IN_PROGRESS' }
      let(:steps) do
        [
          { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'IN_PROGRESS' },
          { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
        ]
      end
      let(:error) { nil }
      let(:end_time) { nil }

      context 'when it has been more than 24 hours since Lighthouse started processing a Lighthouse526DocumentUpload' do
        it 'logs a processing timeout metric to statsd' do
          Timecop.freeze(start_time + 2.days) do
            expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(
              'api.form526.lighthouse_document_upload_processing_status.veteran_upload.processing_timeout'
            )
          end
        end
      end

      context 'when it has been less than 24 hours since Lighthouse started processing a Lighthouse526DocumentUpload' do
        it 'does not log a processing timeout metric to statsd' do
          Timecop.freeze(start_time + 2.hours) do
            expect { described_class.call(uploads, status_response) }.not_to trigger_statsd_increment(
              'api.form526.lighthouse_document_upload_processing_status.veteran_upload.processing_timeout'
            )
          end
        end
      end

      context 'when updating multiple records' do
        let!(:first_pending_polling_document) { create(:lighthouse526_document_upload, aasm_state: 'pending') }
        let!(:second_pending_polling_document) { create(:lighthouse526_document_upload, aasm_state: 'pending') }

        let(:status_response) do
          {
            'data' => {
              'statuses' => [
                {
                  'requestId' => first_pending_polling_document.lighthouse_document_request_id,
                  'time' => {
                    'startTime' => start_time_in_unix_milliseconds,
                    'endTime' => end_time_in_unix_milliseconds
                  },
                  'status' => 'SUCCESS'
                }, {
                  'requestId' => second_pending_polling_document.lighthouse_document_request_id,
                  'time' => {
                    'startTime' => start_time_in_unix_milliseconds,
                    'endTime' => end_time_in_unix_milliseconds
                  },
                  'status' => 'FAILED',
                  'error' => {
                    'detail' => 'Something went wrong',
                    'step' => 'BENEFITS_GATEWAY_SERVICE'
                  }
                }
              ],
              'requestIdsNotFound' => [
                0
              ]
            }
          }
        end

        it 'updates each record status properly' do
          described_class.call(Lighthouse526DocumentUpload.all, status_response)

          expect(first_pending_polling_document.reload.aasm_state).to eq('completed')
          expect(second_pending_polling_document.reload.aasm_state).to eq('failed')
        end
      end
    end

    describe 'document type in statsd metrics' do
      # Helper method to generate identical responses that vary only in document request id
      def mock_success_response(request_id)
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => request_id,
                'status' => 'SUCCESS',
                'time' => { 'startTime' => start_time_in_unix_milliseconds, 'endTime' => end_time_in_unix_milliseconds }
              }
            ]
          }
        }
      end

      before do
        # Stub update behavior; tests metrics keys include the correct document type
        allow_any_instance_of(BenefitsDocuments::Form526::UploadStatusUpdater).to receive(:update_status)
        allow_any_instance_of(Lighthouse526DocumentUpload).to receive(:completed?).and_return(true)
      end

      shared_examples 'correct statsd metric' do |document_type, metrics_key|
        let(:document_upload) { create(:lighthouse526_document_upload, document_type:) }
        let(:uploads) { Lighthouse526DocumentUpload.where(id: document_upload.id) }
        let(:status_response) { mock_success_response(document_upload.lighthouse_document_request_id) }

        it "increments the correct statsd metric for #{document_type}" do
          expect { described_class.call(uploads, status_response) }.to trigger_statsd_increment(metrics_key)
        end
      end

      it_behaves_like 'correct statsd metric', 'BDD Instructions',
                      'api.form526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
      it_behaves_like 'correct statsd metric', 'Form 0781',
                      'api.form526.lighthouse_document_upload_processing_status.form_0781.complete'
      it_behaves_like 'correct statsd metric', 'Form 0781a',
                      'api.form526.lighthouse_document_upload_processing_status.form_0781a.complete'
      it_behaves_like 'correct statsd metric', 'Veteran Upload',
                      'api.form526.lighthouse_document_upload_processing_status.veteran_upload.complete'
    end
  end

  describe 'logging when Form 0781 document upload fails' do
    let(:form0781_document_upload) { create(:lighthouse526_document_upload, document_type: 'Form 0781') }
    let(:uploads) { Lighthouse526DocumentUpload.where(id: form0781_document_upload.id) }
    let(:status_response) do
      {
        'data' => {
          'statuses' => [
            {
              'requestId' => form0781_document_upload.lighthouse_document_request_id,
              'status' => 'FAILED',
              'time' => { 'startTime' => start_time_in_unix_milliseconds, 'endTime' => end_time_in_unix_milliseconds },
              'steps' => [
                { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'FAILED' },
                { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
              ],
              'error' => { 'detail' => 'VBMS System Outage', 'step' => 'CLAIMS_EVIDENCE' }
            }
          ]
        }
      }
    end

    let(:submission) { form0781_document_upload.form526_submission }

    before do
      allow_any_instance_of(BenefitsDocuments::Form526::UploadStatusUpdater).to receive(:update_status)
      allow_any_instance_of(Lighthouse526DocumentUpload).to receive(:failed?).and_return(true)
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs the latest_status_response to the Rails logger' do
      described_class.call(uploads, status_response)

      expect(Rails.logger).to have_received(:warn).with(
        'Benefits Documents API responded with a failed document upload status', {
          form526_submission_id: submission.id,
          document_type: form0781_document_upload.document_type,
          failure_step: 'CLAIMS_EVIDENCE',
          lighthouse_document_request_id: form0781_document_upload.lighthouse_document_request_id,
          user_uuid: submission.user_uuid
        }
      )
    end
  end
end
