# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/service'
require 'lighthouse_document'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Service do
  subject { service }

  let(:user) { create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:service) { BenefitsDocuments::Service.new(user) }

  describe '#queue_document_upload' do
    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
      token = 'abcd1234'
      allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
      user.user_account_uuid = user_account.id
      user.save!
    end

    describe 'when uploading single file' do
      let(:upload_file) do
        f = Tempfile.new(['file with spaces', '.jpg'])
        f.write('test')
        f.rewind
        Rack::Test::UploadedFile.new(f.path, 'image/jpeg')
      end

      let(:params) do
        {
          file_number: 'xyz',
          claimId: '1',
          file: upload_file,
          trackedItemIds: ['1'], # Lighthouse expects an array for tracked items
          documentType: 'L023',
          password: nil
        }
      end

      context 'when cst_synchronous_evidence_uploads is false' do
        before { Flipper.disable(:cst_synchronous_evidence_uploads) }

        it 'enqueues a job' do
          expect do
            service.queue_document_upload(params)
          end.to change(Lighthouse::EvidenceSubmissions::DocumentUpload.jobs, :size).by(1)
        end

        context 'when cst_send_evidence_submission_failure_emails is true' do
          before { Flipper.enable(:cst_send_evidence_submission_failure_emails) }

          it 'records evidence submission' do
            subject.queue_document_upload(params)
            expect(EvidenceSubmission.count).to eq(1)
          end
        end

        context 'when cst_send_evidence_submission_failure_emails is false' do
          before { Flipper.disable(:cst_send_evidence_submission_failure_emails) }

          it 'does not record an evidence submission' do
            expect do
              service.queue_document_upload(params)
            end.not_to change(EvidenceSubmission, :count)
          end
        end
      end

      it 'does not enqueue a job when cst_synchronous_evidence_uploads is true' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_pdf') do
          Flipper.enable(:cst_synchronous_evidence_uploads)
          expect do
            service.queue_document_upload(params)
          end.not_to change(Lighthouse::EvidenceSubmissions::DocumentUpload.jobs, :size)
          expect(EvidenceSubmission.count).to eq(0)
        end
      end
    end
  end
end
