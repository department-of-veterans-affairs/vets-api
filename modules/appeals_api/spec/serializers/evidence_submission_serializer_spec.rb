# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }
  let(:notice_of_disagreement) { AppealsApi::NoticeOfDisagreement.find(evidence_submission.supportable_id) }

  it 'serializes the evidence submission properly' do
    expect(rendered_hash.keys.count).to be 9
    expect(rendered_hash).to include(
      {
        id: evidence_submission.id,
        status: evidence_submission.status,
        appeal_type: 'NoticeOfDisagreement',
        appeal_id: notice_of_disagreement.id
      }
    )
  end
end
