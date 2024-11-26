# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/service'
require 'lighthouse_document'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Service do
  let(:user) { FactoryBot.create(:user, :loa3) }
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

      let(:document) do
        LighthouseDocument.new(
          claim_id: 1,
          file_obj: upload_file,
          file_name: File.basename(upload_file.path)
        )
      end

      let(:params) do
        {
          file_number: 'xyz',
          claimId: 1,
          file: upload_file,
          trackedItemId: [1],
          documentType: 'L023',
          password: nil
        }
      end

      it 'enqueues a job when cst_synchronous_evidence_uploads is false' do
        Flipper.disable(:cst_synchronous_evidence_uploads)
        expect do
          service.queue_document_upload(params)
        end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)
      end

      it 'does not enqueue a job when cst_synchronous_evidence_uploads is true' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_pdf') do
          Flipper.enable(:cst_synchronous_evidence_uploads)
          expect do
            service.queue_document_upload(params)
          end.not_to change(Lighthouse::DocumentUpload.jobs, :size)
        end
      end
    end
  end
end
