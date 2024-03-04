# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'
require 'lighthouse/benefits_documents/form526/documents_status_polling_service'

RSpec.describe BenefitsDocuments::Form526::UpdateDocumentsStatusService do
  describe '#call' do
    context 'when a LighthouseDocumentUpload has completed all steps in Lighthouse' do
      let(:pending_document_upload) do 
        create(:lighthouse_document_upload, document_type: 'BDD Instructions', aasm_state: 'pending_bgs_submission')
      end

      before do
        # Mock response from the Lighthouse Document uploads/status endpont
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
          {
            'data': {
              'statuses': [
                {
                  'requestId': pending_document_upload.lighthouse_document_request_id,
                  'status': 'SUCCESS',
                  'time': {
                    'endTime': '499152060'
                  },
                  'steps': [
                    {
                      'name': 'CLAIMS_EVIDENCE',
                      'status': 'SUCCESS'
                    },
                    {
                      'name': 'BENEFITS_GATEWAY_SERVICE',
                      'status': 'SUCCESS'
                    }
                  ]  
                }
              ]
            }
          }.to_json
        )
      end

      it 'transitions that document to the complete state' do
        uploads = LighthouseDocumentUpload.where(id: pending_document_upload.id)
        expect { described_class.call(uploads) }.to change(pending_document_upload, :aasm_state)
          .to('complete')

        # expect { status_updater.update_status }.to change(bgs_pending_upload, :aasm_state)
        # .from('pending_bgs_submission').to('complete')
        # expect {
        #   described_class.call(uploads)
        # }.to change { pending_document_upload.aasm_state }.to()
        # uploads = LighthouseDocumentUpload.where(id: pending_document_upload.id)
        # described_class.call(uploads)

        # expect(pending_document_upload.aasm_state).to eq('complete')
        # Not sure why I need to reload this one it wasn't capturing the state transition with the block syntax
        # expect(pending_document_upload.reload.aasm_state).to eq('complete')
      end

      it 'logs the document completion to DataDog' do
        uploads = LighthouseDocumentUpload.where(id: pending_document_upload.id)
        expect { described_class.call(uploads) }.to trigger_statsd_increment(
          'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
        )
      end
    end

    context 'when Lighthouse fails to submit a document to VBMS' do
      let(:pending_vbms_document_upload) do
        create(:lighthouse_document_upload, document_type: 'BDD Instructions', aasm_state: 'pending_vbms_submission')
      end

      before do
        # Mock response from the Lighthouse Document uploads/status endpont
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
          {
            'data': {
              'statuses': [
                {
                  'requestId': pending_vbms_document_upload.lighthouse_document_request_id,
                  'status': 'FAILED',
                  'steps': [
                    {
                      'name': 'CLAIMS_EVIDENCE',
                      'status': 'FAILED'
                    },
                    {
                      'name': 'BENEFITS_GATEWAY_SERVICE',
                      'status': 'NOT_STARTED'
                    },
                  ],
                  'error': {
                    'detail': 'VBMS System Outage',
                    'step': 'CLAIMS_EVIDENCE'
                  }
                }
              ]
            }
          }.to_json
        )
      end

      it 'transitions the document to the failed_vbms_submission state' do
        uploads = LighthouseDocumentUpload.where(id: pending_vbms_document_upload.id)
        described_class.call(uploads)

        # Not sure why I need to reload this one it wasn't capturing the state transition with the block syntax
        expect(pending_vbms_document_upload.reload.aasm_state).to eq('failed_vbms_submission')
      end

      it 'logs the document failure to DataDog' do
        uploads = LighthouseDocumentUpload.where(id: pending_vbms_document_upload.id)
        expect { described_class.call(uploads) }.to trigger_statsd_increment(
          'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.vbms_submission_failed'
        )
      end
    end

    context 'when Lighthouse fails to submit a document to BGS' do
      let(:pending_bgs_document_upload) do
        create(:lighthouse_document_upload, document_type: 'BDD Instructions', aasm_state: 'pending_bgs_submission')
      end

      before do
        # Mock response from the Lighthouse Document uploads/status endpont
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
          {
            'data': {
              'statuses': [
                {
                  'requestId': pending_bgs_document_upload.lighthouse_document_request_id,
                  'status': 'FAILED',
                  'steps': [
                    {
                      'name': 'CLAIMS_EVIDENCE',
                      'status': 'SUCCESS'
                    },
                    {
                      'name': 'BENEFITS_GATEWAY_SERVICE',
                      'status': 'FAILED'
                    },
                  ],
                  'error': {
                    'detail': 'BGS System Outage',
                    'step': 'BENEFITS_GATEWAY_SERVICE'
                  }
                }
              ]
            }
          }.to_json
        )
      end

      it 'transitions the document to the failed_bgs_submission state' do
        uploads = LighthouseDocumentUpload.where(id: pending_bgs_document_upload.id)
        described_class.call(uploads)

        # Not sure why I need to reload this one it wasn't capturing the state transition with the block syntax
        expect(pending_bgs_document_upload.reload.aasm_state).to eq('failed_bgs_submission')
      end

      it 'logs the document failure to DataDog' do
        uploads = LighthouseDocumentUpload.where(id: pending_bgs_document_upload.id)
        expect { described_class.call(uploads) }.to trigger_statsd_increment(
          'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.bgs_submission_failed'
        )
      end
    end

    describe 'document type in statsd metrics' do
      # Helper method, responses will be the same just with different document request ids
      def mock_success_response(request_id)
        {
          'data': {
            'statuses': [
              {
                'requestId': request_id,
              }
            ]
          }
        }.to_json
      end

      before do
        # Stub update behavior; we are just testing metrics keys include the correct document type
        allow_any_instance_of(BenefitsDocuments::Form526::UploadStatusUpdater).to receive(:update_status)
        allow_any_instance_of(BenefitsDocuments::Form526::UploadStatusUpdater).to receive(:completed?).and_return(true)
      end

      context 'When the document is BDD Instructions' do
        let(:bdd_instruction_upload) { create(:lighthouse_document_upload, document_type: 'BDD Instructions') }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
            mock_success_response(bdd_instruction_upload.lighthouse_document_request_id)
          )
        end

        it 'increments the correct statsd metric' do
          # Still maybe better way to do this
          uploads = LighthouseDocumentUpload.where(id: bdd_instruction_upload.id)
          expect { described_class.call(uploads) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
          )
        end
      end

      context 'When the document is a Form 0781' do
        let(:form_0781_upload) { create(:lighthouse_document_upload, document_type: 'Form 0781') }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
            mock_success_response(form_0781_upload.lighthouse_document_request_id)
          )
        end

        it 'increments the correct statsd metric' do
          uploads = LighthouseDocumentUpload.where(id: form_0781_upload.id)
          expect { described_class.call(uploads) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.form_0781.complete'
          )
        end
      end

      context 'When the document is a Form 0781a' do
        let(:form_0781a_upload) { create(:lighthouse_document_upload, document_type: 'Form 0781a') }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
            mock_success_response(form_0781a_upload.lighthouse_document_request_id)
          )
        end

        it 'increments the correct statsd metric' do
          uploads = LighthouseDocumentUpload.where(id: form_0781a_upload.id)
          expect { described_class.call(uploads) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.form_0781a.complete'
          )
        end
      end

      context 'When the document is a Veteran Upload' do
        let(:veteran_upload) { create(:lighthouse_document_upload, document_type: 'Veteran Upload') }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
            mock_success_response(veteran_upload.lighthouse_document_request_id)
          )
        end

        it 'increments the correct statsd metric' do
          uploads = LighthouseDocumentUpload.where(id: veteran_upload.id)
          expect { described_class.call(uploads) }.to trigger_statsd_increment(
            'api.form_526.lighthouse_document_upload_processing_status.veteran_upload.complete'
          )
        end
      end
    end
  end
end
