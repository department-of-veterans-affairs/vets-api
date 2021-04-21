# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission, :with_detail, :with_nod) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }

  it 'includes guid' do
    expect(rendered_hash[:id]).to eq evidence_submission.guid
  end

  it 'includes :appeal_type' do
    expect(rendered_hash[:appeal_type]).to eq 'NoticeOfDisagreement'
  end

  it 'includes :appeal_id' do
    expect(rendered_hash[:appeal_id]).to eq evidence_submission.supportable.id
  end

  it "truncates :detail value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
    max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
    expect(rendered_hash[:detail].length).to eq(max_length_plus_ellipses)
  end
end
