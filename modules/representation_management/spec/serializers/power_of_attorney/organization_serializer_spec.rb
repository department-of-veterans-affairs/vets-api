# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OrganizationSerializer' do
  before do
    create(:organization, poa: 'og1')
  end

  def organization
    Veteran::Service::Organization.find('og1')
  end

  it 'can serialize an organization' do
    result = serialize(organization,
                       serializer_class: RepresentationManagement::PowerOfAttorney::OrganizationSerializer)
    attributes = JSON.parse(result)['data']['attributes']

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
                                     phone
                                     type
                                     name])
  end
end
