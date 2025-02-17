# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmission, type: :model do
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:upload_submission) { create(:upload_submission) }
  let(:evidence_submission) do
    create(:evidence_submission, supportable: notice_of_disagreement, upload_submission:)
  end

  it 'responds to supportable' do
    expect(evidence_submission.respond_to?(:supportable)).to be(true)
  end

  it 'has an association with the supportable' do
    expect(evidence_submission.supportable).to eq(notice_of_disagreement)
  end

  it 'has an association with the upload submission' do
    expect(evidence_submission.upload_submission).to eq(upload_submission)
  end

  describe '#submit_to_central_mail!' do
    before { allow(VBADocuments::UploadProcessor).to receive(:perform_async) }

    context 'when the evidence status is "uploaded' do
      let(:upload_submission) { create(:upload_submission, status: 'uploaded') }
      let(:evidence_submission) do
        create(:evidence_submission, supportable: notice_of_disagreement, upload_submission:)
      end

      it 'triggers the UploadProcessor' do
        evidence_submission.submit_to_central_mail!

        expect(VBADocuments::UploadProcessor).to have_received(:perform_async)
                                             .with(upload_submission.guid, caller: evidence_submission.class.name)
      end
    end

    context 'when the evidence status is not "uploaded"' do
      let(:upload_submission) { create(:upload_submission, status: 'received') }
      let(:evidence_submission) do
        create(:evidence_submission, supportable: notice_of_disagreement, upload_submission:)
      end

      it 'does not trigger the UploadProcessor' do
        evidence_submission.submit_to_central_mail!

        expect(VBADocuments::UploadProcessor).not_to have_received(:perform_async)
      end
    end
  end
end
