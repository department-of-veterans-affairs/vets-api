# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::SubmitUpload, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  describe 'perform' do
    let(:appeal_submission) do
      create(:appeal_submission, :with_one_upload, submitted_appeal_uuid: 'e076ea91-6b99-4912-bffc-a8318b9b403f')
    end
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', Mime[:pdf].to_s) }
    let(:appeal_submission_upload) { appeal_submission.appeal_submission_uploads.first }

    context 'when file_data exists' do
      let!(:attachment) do
        VCR.use_cassette('decision_review/200_pdf_validation') do
          drea = DecisionReviewEvidenceAttachment.new(
            guid: appeal_submission_upload.decision_review_evidence_attachment_guid
          )
          drea.set_file_data!(file)
          drea.save!
        end
      end

      it 'calls the documents service api with file body and document data (for NOD)' do
        VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-200_V1') do
          VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
            VCR.use_cassette('decision_review/200_pdf_validation') do
              expect do
                subject.perform_async(appeal_submission_upload.id)
                subject.drain
              end.to trigger_statsd_increment('api.decision_review.get_notice_of_disagreement_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                .and trigger_statsd_increment('api.decision_review.get_notice_of_disagreement_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('api.decision_review.put_notice_of_disagreement_upload.total', times: 1)
                .and trigger_statsd_increment('worker.decision_review.submit_upload.success', times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
              expect(AppealSubmissionUpload.first.lighthouse_upload_id).to eq('59cdb98f-f94b-4aaa-8952-4d1e59b6e40a')
            end
          end
        end
      end
    end
  end
end
