# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmission, type: :model do
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:evidence_submission) { notice_of_disagreement.evidence_submissions.create! }

  it 'responds to status' do
    expect(evidence_submission.respond_to?(:status)).to eq(true)
  end

  it 'responds to supportable' do
    expect(evidence_submission.respond_to?(:supportable)).to eq(true)
  end

  it 'has an association with the supportable' do
    expect(evidence_submission.supportable).to eq(notice_of_disagreement)
  end
end
