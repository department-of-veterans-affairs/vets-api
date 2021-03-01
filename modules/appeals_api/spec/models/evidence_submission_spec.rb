# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmission, type: :model do
  include FixtureHelpers

  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:evidence_submission) { notice_of_disagreement.evidence_submissions.create! }

  it 'should respond to status' do
    expect(evidence_submission.respond_to?(:status)).to eq(true)
  end

  it 'should respond to supportable' do
    expect(evidence_submission.respond_to?(:supportable)).to eq(true)
  end

  it 'should have an association with the supportable' do
    expect(evidence_submission.supportable).to eq(notice_of_disagreement)
  end
end
