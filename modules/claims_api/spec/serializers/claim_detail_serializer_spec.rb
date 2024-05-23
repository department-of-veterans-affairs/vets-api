# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ClaimDetailSerializer do

  let(:claim) { create(:auto_established_claim_with_supporting_documents, :status_established) }
  let(:rendered_hash) { ActiveModelSerializers::SerializableResource.new(claim, {serializer: described_class} ).as_json }
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }
  let(:rendered_documents) do
    [
      {
        id: claim.supporting_documents.first[:id],
        type: "claim_supporting_document",
        md5: claim.supporting_documents.first[:md5],
        filename: claim.supporting_documents.first[:filename],
        uploaded_at: claim.supporting_documents.first[:uploaded_at]
        }
    ]
  end

  it 'includes :status' do
    expect(rendered_attributes[:status]).to eq claim.status
  end

  it 'includes :type' do
    expect(rendered_hash[:data][:type]).to eq "claims_api_claim"
  end

  context 'when uuid is passed in' do
    let(:uuid) { '90770019-ae82-4e5a-b961-4272256ff080' }
    let(:rendered_hash) { ActiveModelSerializers::SerializableResource.new(claim, {serializer: described_class, uuid: } ).as_json }
    it 'includes :id from :uuid' do
      expect(rendered_hash[:data][:id]).to eq uuid
    end
  end

  context 'when uuid is not passed in' do
    it 'includes :id from :evss_id' do
      expect(rendered_hash[:data][:id]).to eq claim.evss_id.to_s
    end
  end

  it 'includes :supporting_documents' do
    expect(rendered_attributes[:supporting_documents]).to eq rendered_documents
  end

end
