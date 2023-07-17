# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
    Flipper.disable(:disability_compensation_lighthouse_document_service_provider)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end

  describe 'perform' do
    let(:upload_data) { [submission.form[Form526Submission::FORM_526_UPLOADS].first] }
    let(:document_data) { double(:document_data, valid?: true) }

    context 'when file_data exists' do
      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
      let!(:attachment) do
        sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
        sea.set_file_data!(file)
        sea.save!
      end

      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('evss/documents/upload_with_errors') do
          expect(EVSSClaimDocument)
            .to receive(:new)
            .with(
              evss_claim_id: submission.submitted_claim_id,
              file_name: upload_data.first['name'],
              tracked_item_id: nil,
              document_type: upload_data.first['attachmentId']
            )
            .and_return(document_data)

          subject.perform_async(submission.id, upload_data)
          expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
          described_class.drain
        end
      end

      context 'with a timeout' do
        it 'logs a retryable error and re-raises the original error' do
          allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
            .and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          subject.perform_async(submission.id, upload_data)
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        end
      end
    end

    context 'when misnamed file_data exists' do
      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1_actually_jpg.png', 'image/png') }
      let!(:attachment) do
        sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
        sea.set_file_data!(file)
        sea.save
      end

      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('evss/documents/upload_with_errors') do
          expect(EVSSClaimDocument)
            .to receive(:new)
            .with(
              evss_claim_id: submission.submitted_claim_id,
              file_name: 'converted_sm_file1_actually_jpg_png.jpg',
              tracked_item_id: nil,
              document_type: upload_data.first['attachmentId']
            )
            .and_return(document_data)

          subject.perform_async(submission.id, upload_data)
          expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
          described_class.drain
        end
      end
    end

    context 'when get_file is nil' do
      let(:attachment) { double(:attachment, get_file: nil) }

      it 'logs a non_retryable_error' do
        subject.perform_async(submission.id, upload_data)
        expect(Form526JobStatus).to receive(:upsert).twice
        expect { described_class.drain }.to raise_error(ArgumentError)
      end
    end
  end
end
