# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::AddressChangeSerializer, type: :serializer do
  subject { described_class.new(address_change).to_json }

  let(:address_change) { build_stubbed(:vye_address_change) }
  let(:data) { JSON.parse(subject) }

  it 'includes :veteran_name' do
    expect(data['veteran_name']).to eq address_change.veteran_name
  end

  it 'includes :address1' do
    expect(data['address1']).to eq address_change.address1
  end

  it 'includes :address2' do
    expect(data['address2']).to eq address_change.address2
  end

  it 'includes :address3' do
    expect(data['address3']).to eq address_change.address3
  end

  it 'includes :address4' do
    expect(data['address4']).to eq address_change.address4
  end

  it 'includes :address5' do
    expect(data['address5']).to eq address_change.address5
  end

  it 'includes :city' do
    expect(data['city']).to eq address_change.city
  end

  it 'includes :state' do
    expect(data['state']).to eq address_change.state
  end

  it 'includes :zip_code' do
    expect(data['zip_code']).to eq address_change.zip_code
  end

  it 'includes :origin' do
    expect(data['origin']).to eq address_change.origin
  end
end
