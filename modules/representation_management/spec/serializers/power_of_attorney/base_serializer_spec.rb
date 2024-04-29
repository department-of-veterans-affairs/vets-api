# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BaseSerializer' do
  before do
    create(:organization, poa: 'og1')
    create(:representative, representative_id: '123', poa_codes: ['rp1'])
  end

  def representative
    Veteran::Service::Representative.find('123')
  end

  def organization
    Veteran::Service::Organization.find('og1')
  end

  def assert_attributes(attributes)
    expect(attributes.keys).to eq(%w[address_line1
                                     address_line2
                                     address_line3
                                     address_type
                                     city
                                     country_name
                                     country_code_iso3
                                     province
                                     international_postal_code
                                     state_code
                                     zip_code
                                     zip_suffix
                                     phone])
  end

  it 'can serialize a representative' do
    result = serialize(representative, serializer_class: RepresentationManagement::PowerOfAttorney::BaseSerializer)
    attributes = JSON.parse(result)['data']['attributes']
    assert_attributes(attributes)
  end

  it 'can serialize an organization' do
    result = serialize(organization, serializer_class: RepresentationManagement::PowerOfAttorney::BaseSerializer)
    attributes = JSON.parse(result)['data']['attributes']
    assert_attributes(attributes)
  end
end
