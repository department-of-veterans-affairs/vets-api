# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReview::SubmitUpload, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  describe 'perform' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
    let(:confirmation_code) { SecureRandom.uuid }
    let(:appeal_submission_id) { '6d0c3dba-8a1f-41be-bd16-59bf22d273e7' }
    let(:upload_data) do
      { "name": 'my_file.pdf',
        "confirmationCode": confirmation_code }
    end

    context 'when file_data exists' do
      let!(:attachment) do
        drea = DecisionReviewEvidenceAttachment.new(guid: confirmation_code)
        drea.set_file_data!(file)
        drea.save!
      end

      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('/decision_review/NOD-GET-UPLOAD-URL-200') do
          VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
            subject.perform_async(user.uuid, appeal_submission_id, upload_data)
            expect_any_instance_of(DecisionReview::Service).to receive(:put_notice_of_disagreement_upload)
            described_class.drain
          end
        end
      end

      it 'raises when the appeal_submission_id is not found' do
        VCR.use_cassette('/decision_review/NOD-GET-UPLOAD-URL-404') do
          subject.perform_async(user.uuid, appeal_submission_id, upload_data)
          expect { described_class.drain }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
