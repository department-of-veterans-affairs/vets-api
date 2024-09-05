# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'power_of_attorney' do
  it 'includes :address_line1' do
    expect(attributes['address_line1']).to eq object.address_line1
  end

  it 'includes :address_line2' do
    expect(attributes['address_line2']).to eq object.address_line2
  end

  it 'includes :address_line3' do
    expect(attributes['address_line3']).to eq object.address_line3
  end

  it 'includes :address_type' do
    expect(attributes['address_type']).to eq object.address_type
  end

  it 'includes :city' do
    expect(attributes['city']).to eq object.city
  end

  it 'includes :country_name' do
    expect(attributes['country_name']).to eq object.country_name
  end

  it 'includes :country_code_iso3' do
    expect(attributes['country_code_iso3']).to eq object.country_code_iso3
  end

  it 'includes :province' do
    expect(attributes['province']).to eq object.province
  end

  it 'includes :international_postal_code' do
    expect(attributes['international_postal_code']).to eq object.international_postal_code
  end

  it 'includes :state_code' do
    expect(attributes['state_code']).to eq object.state_code
  end

  it 'includes :zip_code' do
    expect(attributes['zip_code']).to eq object.zip_code
  end

  it 'includes :zip_suffix' do
    expect(attributes['zip_suffix']).to eq object.zip_suffix
  end

  # phone is on the organization and representative serializer spec
  it 'includes :phone' do
    expect(attributes.keys).to include('phone')
  end
end
