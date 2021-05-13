# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }

  context 'when initialized with an object that cannot be called by the delegated attributes' do
    it 'raises an error' do
      expect { described_class.new(nil).serializable_hash }.to raise_error(NoMethodError)
    end
  end

  it 'includes guid' do
    expect(rendered_hash[:id]).to eq evidence_submission.guid
  end

  it 'includes :appeal_type' do
    expect(rendered_hash[:appeal_type]).to eq 'NoticeOfDisagreement'
  end

  it 'includes :appeal_id' do
    expect(rendered_hash[:appeal_id]).to eq evidence_submission.supportable.id
  end

  it 'includes :updated_at' do
    expect(rendered_hash[:updated_at]).to eq evidence_submission.updated_at
  end

  context 'with a successful status on parent upload' do
    it 'includes :status' do
      expect(rendered_hash[:status]).to eq evidence_submission.status
    end

    it 'includes :code with nil value' do
      expect(rendered_hash[:code]).to be nil
    end

    it 'includes :detail with nil value' do
      expect(rendered_hash[:detail]).to be nil
    end
  end

  context "with 'error' status on parent upload" do
    let(:submission_with_error) { create(:evidence_submission_with_error) }
    let(:rendered_hash) { described_class.new(submission_with_error).serializable_hash }

    it 'includes :status' do
      expect(rendered_hash[:status]).to eq 'error'
    end

    it 'includes :code' do
      expect(rendered_hash[:code]).to eq '404'
    end

    it "truncates :detail value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
      max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
      expect(rendered_hash[:detail].length).to eq(max_length_plus_ellipses)
      expect(submission_with_error.detail).to include rendered_hash[:detail][0, 100]
    end
  end
end
