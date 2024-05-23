# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::AutoEstablishedClaimSerializer do
  let(:auto_established_claim) { build_stubbed(:auto_established_claim) }
  let(:rendered_hash) { ActiveModelSerializers::SerializableResource.new(auto_established_claim, {serializer: described_class} ).as_json }
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes attributes' do
    expect(rendered_attributes[:token]).to eq auto_established_claim.token
  end

  it 'includes :status' do
    expect(rendered_attributes[:status]).to eq auto_established_claim.status
  end

  it 'includes :evss_id' do
    expect(rendered_attributes[:evss_id]).to eq auto_established_claim.evss_id
  end

  it 'includes :flashes' do
    expect(rendered_attributes[:flashes]).to eq auto_established_claim.flashes
  end

  it 'includes :type' do
    expect(rendered_hash[:data][:type]).to eq "claims_api_claim"
  end

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq auto_established_claim.id
  end

end
