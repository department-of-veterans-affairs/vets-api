# frozen_string_literal: true

require 'rails_helper'

describe Vye::AddressChangeSerializer, type: :serializer do
  subject { serialize(address_change, serializer_class: described_class) }

  let(:address_change) { build_stubbed(:vye_address_change) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :veteran_name' do
    expect(attributes['veteran_name']).to eq address_change.veteran_name
  end

  it 'includes :address1' do
    expect(attributes['address1']).to eq address_change.address1
  end

  it 'includes :address2' do
    expect(attributes['address2']).to eq address_change.address2
  end

  it 'includes :address3' do
    expect(attributes['address3']).to eq address_change.address3
  end

  it 'includes :address4' do
    expect(attributes['address4']).to eq address_change.address4
  end

  it 'includes :address5' do
    expect(attributes['address5']).to eq address_change.address5
  end

  it 'includes :city' do
    expect(attributes['city']).to eq address_change.city
  end

  it 'includes :state' do
    expect(attributes['state']).to eq address_change.state
  end

  it 'includes :zip_code' do
    expect(attributes['zip_code']).to eq address_change.zip_code
  end

  it 'includes :origin' do
    expect(attributes['origin']).to eq address_change.origin
  end
end
