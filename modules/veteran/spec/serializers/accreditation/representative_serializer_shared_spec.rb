# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'a representative serializer' do |serializer_class|
  it 'includes the specified model attributes' do
    representative_instance = representative
    result = serialize(representative_instance, serializer_class:)
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
      if attr == 'phone'
        public_send_method = serializer_class == Veteran::Accreditation::VSORepresentativeSerializer ? 'phone_number' : 'phone' # rubocop:disable Layout/LineLength
        expect(attributes[attr]).to eq(representative.public_send(public_send_method))
      else
        expect(attributes[attr]).to eq(representative.public_send(attr))
      end
    end
  end

  it 'includes the distance in miles' do
    representative_instance = representative
    result = serialize(representative_instance, serializer_class:)
    attributes = JSON.parse(result)['data']['attributes']

    expect(attributes['distance']).to eq('2.5')
  end
end
