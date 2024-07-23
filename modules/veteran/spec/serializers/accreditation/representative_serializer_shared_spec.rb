# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'a representative serializer' do |_serializer_class|
  it 'includes :full_name' do
    expect(attributes['full_name']).to eq  "#{representative.first_name} #{representative.last_name}"
  end

  it 'includes :address_line1' do
    expect(attributes['address_line1']).to eq representative.address_line1
  end

  it 'includes :address_line2' do
    expect(attributes['address_line2']).to eq representative.address_line2
  end

  it 'includes :address_line3' do
    expect(attributes['address_line3']).to eq representative.address_line3
  end

  it 'includes :address_type' do
    expect(attributes['address_type']).to eq representative.address_type
  end

  it 'includes :city' do
    expect(attributes['city']).to eq representative.city
  end

  it 'includes :country_name' do
    expect(attributes['country_name']).to eq representative.country_name
  end

  it 'includes :country_code_iso3' do
    expect(attributes['country_code_iso3']).to eq representative.country_code_iso3
  end

  it 'includes :province' do
    expect(attributes['province']).to eq representative.province
  end

  it 'includes :international_postal_code' do
    expect(attributes['international_postal_code']).to eq representative.international_postal_code
  end

  it 'includes :state_code' do
    expect(attributes['state_code']).to eq representative.state_code
  end

  it 'includes :zip_code' do
    expect(attributes['zip_code']).to eq representative.zip_code
  end

  it 'includes :zip_suffix' do
    expect(attributes['zip_suffix']).to eq representative.zip_suffix
  end

  it 'includes :poa_codes' do
    expect(attributes['poa_codes']).to eq representative.poa_codes
  end

  it 'includes :email' do
    expect(attributes['email']).to eq representative.email
  end

  it 'includes :lat' do
    expect(attributes['lat']).to eq representative.lat
  end

  it 'includes :long' do
    expect(attributes['long']).to eq representative.long
  end

  it 'includes :user_types' do
    expect(attributes['user_types']).to eq representative.user_types
  end

  it 'includes :distance' do
    expected_distance = representative.distance / Veteran::Service::Constants::METERS_PER_MILE
    expect(attributes['distance']).to eq expected_distance.to_s
  end
end
