# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'power_of_attorney' do
  it 'includes :address_line1' do
    expect(rendered_attributes[:address_line1]).to eq object.address_line1
  end

  it 'includes :address_line2' do
    expect(rendered_attributes[:address_line2]).to eq object.address_line2
  end

  it 'includes :address_line3' do
    expect(rendered_attributes[:address_line3]).to eq object.address_line3
  end

  it 'includes :address_type' do
    expect(rendered_attributes[:address_type]).to eq object.address_type
  end

  it 'includes :city' do
    expect(rendered_attributes[:city]).to eq object.city
  end

  it 'includes :country_name' do
    expect(rendered_attributes[:country_name]).to eq object.country_name
  end

  it 'includes :country_code_iso3' do
    expect(rendered_attributes[:country_code_iso3]).to eq object.country_code_iso3
  end

  it 'includes :province' do
    expect(rendered_attributes[:province]).to eq object.province
  end

  it 'includes :international_postal_code' do
    expect(rendered_attributes[:international_postal_code]).to eq object.international_postal_code
  end

  it 'includes :state_code' do
    expect(rendered_attributes[:state_code]).to eq object.state_code
  end

  it 'includes :zip_code' do
    expect(rendered_attributes[:zip_code]).to eq object.zip_code
  end

  it 'includes :zip_suffix' do
    expect(rendered_attributes[:zip_suffix]).to eq object.zip_suffix
  end

  # phone is on the organization and representative serializer spec
  it 'includes :zip_suffix' do
    expect(rendered_attributes.keys).to include(:phone)
  end
end
