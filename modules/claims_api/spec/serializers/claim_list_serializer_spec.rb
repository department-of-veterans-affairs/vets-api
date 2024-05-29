# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ClaimListSerializer do
  let(:claims) { create_list(:auto_established_claim, 2) }
  let(:rendered_hash) { ActiveModelSerializers::SerializableResource.new(claims).as_json }
  let(:rendered_claims_attributes) { rendered_hash[:data].first[:attributes] }

  it 'includes multiple records' do
    expect(rendered_hash[:data].count).to eq 2
  end

  it 'includes :status' do
    expect(rendered_claims_attributes[:status]).to eq claims.first.status
  end
end
