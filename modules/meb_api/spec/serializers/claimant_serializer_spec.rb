# frozen_string_literal: true

require 'rails_helper'
require 'dgi/claimant/claimant_response'

describe ClaimantSerializer, type: :serializer do
  subject { serialize(claimant_response, serializer_class: described_class) }

  let(:claimant) { 600_010_259 }
  let(:claimant_response) do
    response = double('response', body: { 'claimant_id' => claimant })
    MebApi::DGI::Claimant::ClaimantResponse.new(201, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :claimant_id' do
    expect(attributes['claimant_id']).to eq claimant.to_s
  end
end
