# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:evidence_submission) { create(:evidence_submission, :with_detail, :with_code) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  context 'when initialized with an object that cannot be called by the delegated attributes' do
    it 'raises an error' do
      expect { described_class.new(nil).serializable_hash }.to raise_error(NoMethodError)
    end
  end

  it 'includes guid' do
    expect(rendered_hash[:id]).to eq evidence_submission.guid
  end

  it 'includes :status' do
    expect(rendered_hash[:status]).to eq evidence_submission.status
  end

  it 'includes :appeal_type' do
    expect(rendered_hash[:appeal_type]).to eq 'NoticeOfDisagreement'
  end

  it 'includes :appeal_id' do
    expect(rendered_hash[:appeal_id]).to eq evidence_submission.supportable.id
  end

  it 'includes :code' do
    expect(rendered_hash[:code]).to eq evidence_submission.code
  end

  it "truncates :detail value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
    max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
    expect(rendered_hash[:detail].length).to eq(max_length_plus_ellipses)
  end

  it 'includes :created_at' do
    expect(rendered_hash[:created_at]).to eq evidence_submission.created_at
  end

  it 'includes :updated_at' do
    expect(rendered_hash[:updated_at]).to eq evidence_submission.updated_at
  end

  it 'does not include any extra attributes' do
    expect(rendered_hash.keys).to eq(%i[id status code detail appeal_type appeal_id location created_at updated_at])
  end
end
