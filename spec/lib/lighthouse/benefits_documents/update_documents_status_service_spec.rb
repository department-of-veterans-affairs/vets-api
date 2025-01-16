# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/update_documents_status_service'
require 'lighthouse/benefits_documents/documents_status_polling_service'

RSpec.describe BenefitsDocuments::UpdateDocumentsStatusService do
  describe '#call' do
    let(:lighthouse_document_upload1) { create(:bd_evidence_submission, request_id: 1) }
    let(:lighthouse_document_upload2) { create(:bd_evidence_submission, request_id: 2) }
    let(:lighthouse_document_upload3) { create(:bd_evidence_submission, request_id: 3) }

    let :document_batch_ids do
      [
        lighthouse_document_upload1.request_id,
        lighthouse_document_upload2.request_id,
        lighthouse_document_upload3.request_id
      ]
    end
    let(:document_batch) do
      EvidenceSubmission.where(request_id: document_batch_ids)
    end

    describe 'process_status_updates' do
      let(:lighthouse_status_response) do
        {
          'data' => {
            'statuses' => [
              {
                'requestId' => lighthouse_document_upload1.request_id,
                'status' => BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
                'error' => nil
              },
              {
                'requestId' => lighthouse_document_upload2.request_id,
                'status' => BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
                'error' => 'ERROR'
              },
              {
                'requestId' => lighthouse_document_upload3.request_id,
                'status' => BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING],
                'error' => nil
              }
            ]
          }
        }
      end

      it 'updates the status of 2 records to FAILED and SUCCESS and leaves one in PENDING' do
        described_class.call(document_batch, lighthouse_status_response)
        es1 = EvidenceSubmission.find_by(request_id: lighthouse_document_upload1.request_id)
        es2 = EvidenceSubmission.find_by(request_id: lighthouse_document_upload2.request_id)
        es3 = EvidenceSubmission.find_by(request_id: lighthouse_document_upload3.request_id)

        expect(es1.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS])
        expect(es1.delete_date).not_to be_nil
        expect(es2.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
        expect(es2.failed_date).not_to be_nil
        expect(es2.acknowledgement_date).not_to be_nil
        expect(es2.error_message).to eq('ERROR')
        expect(es3.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
      end
    end
  end
end
