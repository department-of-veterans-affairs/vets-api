# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::RunUnsuccessfulSubmissions, type: :job do
  let(:uploaded_submission) { create(:upload_submission, :status_uploaded) }
  let(:pending_submission) { create(:upload_submission) }

  let(:subject) { described_class }

  describe '#perform' do
    it 'runs the UploadProcessor for the uploaded UploadSubmission' do
      expect(VBADocuments::UploadProcessor).to receive(:perform_async)
        .with(uploaded_submission.guid, caller: described_class.name).once
      expect(VBADocuments::UploadProcessor).not_to receive(:perform_async)
        .with(pending_submission.guid, caller: described_class.name)
      subject.new.perform
    end
  end
end
