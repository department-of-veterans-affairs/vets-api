# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentativeSerializer' do
  before do
    create(:representative, representative_id: '123', poa_codes: ['rp1'])
  end

  def representative
    Veteran::Service::Representative.find('123')
  end

  it 'can serialize a representative' do
    result = serialize(representative,
                       serializer_class: RepresentationManagement::PowerOfAttorney::RepresentativeSerializer)
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
                                     name
                                     email])
  end
end
