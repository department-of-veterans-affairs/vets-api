# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/update_documents_status_service'
require 'lighthouse/benefits_documents/documents_status_polling_service'

RSpec.describe BenefitsDocuments::UpdateDocumentsStatusService do
  describe '#call' do
    let(:lighthouse_document_upload1) do
      create(:bd_evidence_submission_pending, request_id: 1, job_class: 'BenefitsDocuments::Service')
    end
    let(:lighthouse_document_upload2) do
      create(:bd_evidence_submission_pending, request_id: 2, job_class: 'BenefitsDocuments::Service')
    end
    let(:lighthouse_document_upload3) do
      create(:bd_evidence_submission_pending, request_id: 3, job_class: 'BenefitsDocuments::Service')
    end

    let :pending_evidence_submission_ids do
      [
        lighthouse_document_upload1.request_id,
        lighthouse_document_upload2.request_id,
        lighthouse_document_upload3.request_id
      ]
    end
    let(:pending_evidence_submission_batch) do
      EvidenceSubmission.where(request_id: pending_evidence_submission_ids)
    end

    describe 'process_status_updates' do
      before do
        allow(Rails.logger).to receive(:warn)
      end

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
            ],
            'requestIdsNotFound' => ['1234']
          }
        }
      end

      it 'updates the status of 2 records to FAILED and SUCCESS and leaves one in PENDING' do
        expect(lighthouse_document_upload1.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
        expect(lighthouse_document_upload2.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
        expect(lighthouse_document_upload3.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])

        described_class.call(pending_evidence_submission_batch, lighthouse_status_response)

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

      it 'logs when requestIds aren\'t found' do
        described_class.call(pending_evidence_submission_batch, lighthouse_status_response)
        expect(Rails.logger).to have_received(:warn).with(
          'Benefits Documents API cannot find these requestIds and cannot verify upload status',
          { request_ids: ['1234'] }
        )
      end
    end
  end
end
