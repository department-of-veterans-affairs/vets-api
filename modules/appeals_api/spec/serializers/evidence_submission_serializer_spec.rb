# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission, :with_details) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }
  let(:notice_of_disagreement) { AppealsApi::NoticeOfDisagreement.find(evidence_submission.supportable_id) }

  it 'includes id' do
    expect(rendered_hash[:id]).to eq evidence_submission.id
  end

  it 'includes :appeal_type' do
    expect(rendered_hash[:appeal_type]).to eq 'NoticeOfDisagreement'
  end

  it 'includes :appeal_id' do
    expect(rendered_hash[:appeal_id]).to eq notice_of_disagreement.id
  end

  it "truncates :details value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
    max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
    expect(rendered_hash[:details].length).to eq(max_length_plus_ellipses)
  end
end
