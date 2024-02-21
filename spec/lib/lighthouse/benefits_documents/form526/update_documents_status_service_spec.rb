# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'
require 'lighthouse/benefits_documents/form526/documents_status_polling_service'

RSpec.describe Lighthouse::BenefitsDocuments::Form526::UpdateDocumentsStatusService do
  describe '#call' do
    context 'when Lighthouse reports they have successfully submitted a document to VBMS' do
      let(:pending_vbms_document_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission') }
      let(:vbms_status_complete_response) do
        {
          data: {
            statuses: [
              {
                requestId: pending_vbms_document_upload.lighthouse_document_request_id,
                status: 'IN_PROGRESS',
                steps: [
                  {
                    name: 'CLAIMS_EVIDENCE',
                    status: 'COMPLETE'
                  },
                  {
                    name: 'BENEFITS_GATEWAY_SERVICE',
                    status: 'NOT_STARTED'
                  }
                ]
              }
            ]
          }
        }
      end

      before do
        allow(Lighthouse::BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).and_return(
          vbms_status_complete_response
        )
      end

      it 'updates the LighthouseDocumentUpload state to pending_bgs_submission' do
        expect(described_class.new([pending_vbms_document_upload])).call.to change(
          pending_vbms_document_upload.aasm_state
        ).from('pending_vbms_submission').to('pending_bgs_submission')
      end
    end
  end
end
