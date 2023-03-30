# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmission, type: :model do
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:upload_submission) { create(:upload_submission) }
  let(:evidence_submission) do
    create :evidence_submission, supportable: notice_of_disagreement, upload_submission:
  end

  it 'responds to supportable' do
    expect(evidence_submission.respond_to?(:supportable)).to eq(true)
  end

  it 'has an association with the supportable' do
    expect(evidence_submission.supportable).to eq(notice_of_disagreement)
  end

  it 'has an association with the upload submission' do
    expect(evidence_submission.upload_submission).to eq(upload_submission)
  end
end
