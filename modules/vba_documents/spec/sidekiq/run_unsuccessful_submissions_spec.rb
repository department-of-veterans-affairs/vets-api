# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::RunUnsuccessfulSubmissions, type: :job do
  let(:uploaded_submission) { create(:upload_submission, :status_uploaded) }
  let(:pending_submission) { create(:upload_submission) }
  let(:uploaded_appeals_evidence_submission) do
    create(:upload_submission, :status_uploaded, consumer_name: 'appeals_api_sc_evidence_submission')
  end

  let(:subject) { described_class.new }

  describe '#perform' do
    context 'when the decision_review_delay_evidence feature is enabled' do
      before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'calls the UploadProcessor for the uploaded UploadSubmission' do
        expect(VBADocuments::UploadProcessor).to receive(:perform_async)
          .with(uploaded_submission.guid, caller: described_class.name).once
        subject.perform
      end

      it 'does not call the UploadProcessor for the pending UploadSubmission' do
        expect(VBADocuments::UploadProcessor).not_to receive(:perform_async)
          .with(pending_submission.guid, caller: described_class.name)
        subject.perform
      end

      it 'does not call the UploadProcessor for the uploaded appeals evidence submission' do
        expect(VBADocuments::UploadProcessor).not_to receive(:perform_async)
          .with(uploaded_appeals_evidence_submission.guid, caller: described_class.name)
        subject.perform
      end
    end

    context 'when the decision_review_delay_evidence feature is disabled' do
      before { Flipper.disable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'calls the UploadProcessor for the uploaded UploadSubmission' do
        expect(VBADocuments::UploadProcessor).to receive(:perform_async)
          .with(uploaded_submission.guid, caller: described_class.name).once
        subject.perform
      end

      it 'does not call the UploadProcessor for the pending UploadSubmission' do
        expect(VBADocuments::UploadProcessor).not_to receive(:perform_async)
          .with(pending_submission.guid, caller: described_class.name)
        subject.perform
      end

      it 'calls the UploadProcessor for the uploaded appeals evidence submission' do
        expect(VBADocuments::UploadProcessor).to receive(:perform_async)
          .with(uploaded_appeals_evidence_submission.guid, caller: described_class.name)
        subject.perform
      end
    end
  end
end
