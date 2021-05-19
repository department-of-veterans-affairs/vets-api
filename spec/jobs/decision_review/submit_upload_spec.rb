# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReview::SubmitUpload, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'perform' do
    let(:appeal_submission) { create(:appeal_submission, :with_one_upload, submitted_appeal_uuid: "a134c32f-4cc8-49cb-9c84-c316a3291fe2") }
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', Mime[:pdf].to_s) }
    let(:appeal_submission_upload) { appeal_submission.appeal_submission_uploads.first }

    context 'when file_data exists' do
      let!(:attachment) do
        drea = DecisionReviewEvidenceAttachment.new(
          guid: appeal_submission_upload.decision_review_evidence_attachment_guid
        )
        drea.set_file_data!(file)
        drea.save!
      end

      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('/decision_review/NOD-GET-UPLOAD-URL-200') do
          VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
            subject.perform_async(appeal_submission_upload.id)
            expect_any_instance_of(DecisionReview::Service).to receive(:put_notice_of_disagreement_upload)
            described_class.drain
            expect(AppealSubmissionUpload.first.lighthouse_upload_id).to eq('bffbeac7-b128-4a01-a5aa-09f80698709d')
          end
        end
      end
    end
  end
end
