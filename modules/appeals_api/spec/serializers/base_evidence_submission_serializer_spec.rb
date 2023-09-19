# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::BaseEvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission_v0) }

  context 'by default' do
    let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }

    it 'serializes the submission correctly' do
      expect(rendered_hash).to eq(
        {
          data: {
            id: evidence_submission.guid,
            type: :evidenceSubmission,
            attributes: {
              status: evidence_submission.status,
              code: evidence_submission.code,
              detail: evidence_submission.detail,
              location: nil,
              appealId: evidence_submission.supportable_id,
              appealType: 'NoticeOfDisagreement',
              createDate: evidence_submission.created_at,
              updateDate: evidence_submission.updated_at
            }
          }
        }
      )
    end
  end

  context 'with location' do
    let(:expected_location) { 'http://some.fakesite.com/path/uuid' }
    let(:rendered_hash) do
      described_class.new(evidence_submission, { params: { render_location: true } }).serializable_hash
    end

    before do
      allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
    end

    it 'includes the location in the serialized submission' do
      expect(rendered_hash.dig(:data, :attributes, :location)).to eq(expected_location)
    end
  end
end
