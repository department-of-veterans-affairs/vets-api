# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::RunUnsuccessfulSubmissions, type: :job do
  let(:uploaded_submission) { create(:upload_submission, :status_uploaded) }
  let(:uploaded_submission_11_min_ago) { create(:upload_submission, :status_uploaded_11_min_ago) }
  let(:pending_submission) { create(:upload_submission) }

  let(:subject) { described_class }

  describe '#perform' do
    it 'runs the UploadProcessor for the uploaded UploadSubmission' do
      expect(VBADocuments::UploadProcessor).to receive(:perform_async).with(uploaded_submission_11_min_ago.guid).once
      expect(VBADocuments::UploadProcessor).not_to receive(:perform_async).with(uploaded_submission.guid)
      expect(VBADocuments::UploadProcessor).not_to receive(:perform_async).with(pending_submission.guid)
      subject.new.perform
    end

    it 'picks up submissions that were previously skipped for being too young' do
      upload = uploaded_submission
      subject.new.perform
      Timecop.travel(15.minutes.from_now) do
        expect(VBADocuments::UploadProcessor).to receive(:perform_async).with(upload.guid).once
        subject.new.perform
      end
    end
  end
end
