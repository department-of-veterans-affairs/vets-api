# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ClaimDetailSerializer, type: :serializer do
  subject { serialize(claim, serializer_class: described_class) }

  let(:claim) { create(:auto_established_claim_with_supporting_documents, :established) }
  let(:uuid) { '90770019-ae82-4e5a-b961-4272256ff080' }
  let(:rendered_documents) do
    [
      {
        id: claim.supporting_documents.first[:id],
        type: 'claim_supporting_document',
        header_hash: claim.supporting_documents.first[:header_hash],
        filename: claim.supporting_documents.first[:filename],
        uploaded_at: claim.supporting_documents.first[:uploaded_at]
      }
    ]
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { claim.data }

  context 'when uuid is passed in' do
    subject { serialize(claim, { serializer_class: described_class, params: { uuid: } }) }

    it 'includes :id from :uuid' do
      expect(data['id']).to eq uuid
    end
  end

  context 'when uuid is not passed in' do
    it 'includes :id from :evss_id' do
      expect(data['id']).to eq claim.evss_id.to_s
    end
  end

  it 'includes :status' do
    expect(attributes['status']).to eq claim.status
  end

  it 'includes :type' do
    expect(data['type']).to eq 'claims_api_claim'
  end

  it 'includes :supporting_documents' do
    expect(attributes['supporting_documents'].size).to eq rendered_documents.size
  end

  it 'includes :supporting_documents with attributes' do
    expect(attributes['supporting_documents'].first.keys).to eq rendered_documents.first.keys.map(&:to_s)
  end

  it 'includes base keys' do
    base_keys = %w[
      date_filed
      min_est_date
      max_est_date
      open
      documents_needed
      development_letter_sent
      decision_letter_sent
      requested_decision
      claim_type
    ]
    expect(attributes.keys).to include(*base_keys)
  end
end
