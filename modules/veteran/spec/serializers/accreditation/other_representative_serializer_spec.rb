# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::Accreditation::OtherRepresentativeSerializer do
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
           email: 'email@example.com',
           user_types: ['attorney'])
  end

  it 'includes the specified model attributes' do
    representative = Veteran::Service::Representative
                     .where(representative_id: '123abc')
                     .select('veteran_representatives.*, 4023.36 as distance')
                     .first
    result = serialize(representative, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    %w[full_name
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
       user_types].each do |attr|
      expect(attributes[attr]).to eq(representative.public_send(attr))
    end
  end

  it 'includes the distance in miles' do
    representative = Veteran::Service::Representative
                     .where(representative_id: '123abc')
                     .select('veteran_representatives.*, 4023.36 as distance')
                     .first
    result = serialize(representative, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes['distance']).to eq('2.5')
  end

  it 'does not include any extra attributes' do
    representative = Veteran::Service::Representative
                     .where(representative_id: '123abc')
                     .select('veteran_representatives.*, 4023.36 as distance')
                     .first
    result = serialize(representative, serializer_class: described_class)

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
                                     distance
                                     user_types])
  end
end
