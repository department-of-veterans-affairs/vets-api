# frozen_string_literal: true

require 'rails_helper'
require_relative 'representative_serializer_shared_spec'

RSpec.describe 'VSORepresentativeSerializer' do
  before do
    create(:representative,
           representative_id: '123abc',
           first_name: 'Bob',
           last_name: 'Law',
           address_line1: '123 East Main St',
           address_line2: 'Suite 1',
           address_line3: 'Address Line 3',
           address_type: 'DOMESTIC',
           city: 'My City',
           country_name: 'United States of America',
           country_code_iso3: 'USA',
           province: 'A Province',
           international_postal_code: '12345',
           state_code: 'ZZ',
           zip_code: '12345',
           zip_suffix: '6789',
           lat: '39',
           long: '-75',
           poa_codes: ['A123'],
           phone: '222-222-2222',
           email: 'email@example.com')
  end

  def representative
    Veteran::Service::Representative
      .where(representative_id: '123abc')
      .select("veteran_representatives.*, 4023.36 as distance, ARRAY['org1_name', 'org2_name', 'org3_name'] as organization_names") # rubocop:disable Layout/LineLength
      .first
  end

  include_examples 'a representative serializer', Veteran::Accreditation::VSORepresentativeSerializer

  it 'includes organization_names' do
    result = serialize(representative, serializer_class: Veteran::Accreditation::VSORepresentativeSerializer)
    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes['organization_names']).to eq(%w[org1_name org2_name org3_name])
  end

  it 'does not include any extra attributes' do
    result = serialize(representative, serializer_class: Veteran::Accreditation::VSORepresentativeSerializer)
    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes.keys).to eq(%w[full_name
                                     address_line1
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
                                     poa_codes
                                     phone
                                     email
                                     lat
                                     long
                                     user_types
                                     distance
                                     organization_names])
  end
end
