# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { create(:evidence_submission) }
  let(:rendered_hash) { described_class.new(evidence_submission).serializable_hash }

  it 'serializes the NOD properly' do
    expect(rendered_hash).to eq(
      {
        data: {
          type: :evidenceSubmission,
          id: evidence_submission.id.to_s,
          attributes: {
            status: evidence_submission.status
          }
        }
      }
    )
  end

  it 'has the correct top level keys' do
    expect(rendered_hash.keys.count).to be 1
    expect(rendered_hash).to have_key :data
  end

  it 'has the correct data keys' do
    expect(rendered_hash[:data].keys.count).to be 3
    expect(rendered_hash[:data]).to have_key :type
    expect(rendered_hash[:data]).to have_key :id
    expect(rendered_hash[:data]).to have_key :attributes
  end

  it 'has the correct attribute keys' do
    expect(rendered_hash[:data][:attributes].keys.count).to be 1
    expect(rendered_hash[:data][:attributes]).to have_key :status
  end

  it 'has the correct type' do
    expect(rendered_hash[:data][:type]).to eq :evidenceSubmission
  end
end
