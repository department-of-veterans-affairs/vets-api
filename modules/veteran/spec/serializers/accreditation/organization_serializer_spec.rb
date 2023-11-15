# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::Accreditation::OrganizationSerializer do
  before do
    create(:organization,
           name: 'Bob Law',
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
           poa: 'A12',
           phone: '222-222-2222')
  end

  it 'includes the specified model attributes' do
    organization = Veteran::Service::Organization
                   .where(poa: 'A12')
                   .select('veteran_organizations.*, 4023.36 as distance')
                   .first
    result = serialize(organization, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    %w[name
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
       phone
       lat
       long].each do |attr|
      expect(attributes[attr]).to eq(organization.public_send(attr))
    end
  end

  it 'includes the distance in miles' do
    organization = Veteran::Service::Organization
                   .where(poa: 'A12')
                   .select('veteran_organizations.*, 4023.36 as distance')
                   .first
    result = serialize(organization, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes['distance']).to eq('2.5')
  end

  it 'includes the poa_code' do
    organization = Veteran::Service::Organization
                   .where(poa: 'A12')
                   .select('veteran_organizations.*, 4023.36 as distance')
                   .first
    result = serialize(organization, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes['poa_code']).to eq('A12')
  end

  it 'does not include any extra attributes' do
    organization = Veteran::Service::Organization
                   .where(poa: 'A12')
                   .select('veteran_organizations.*, 4023.36 as distance')
                   .first
    result = serialize(organization, serializer_class: described_class)

    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes.keys).to eq(%w[name
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
                                     poa_code
                                     phone
                                     lat
                                     long
                                     distance])
  end
end
