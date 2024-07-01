# frozen_string_literal: true

require 'rails_helper'
require_relative 'representative_serializer_shared_spec'

describe Veteran::Accreditation::BaseRepresentativeSerializer, type: :serializer do
  subject { serialize(representative, serializer_class: described_class) }

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

  let(:representative) do
    Veteran::Service::Representative
      .where(representative_id: '123abc')
      .select('veteran_representatives.*, 4023.36 as distance')
      .first
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  include_examples 'a representative serializer'

  it 'includes :id' do
    expect(data['id']).to eq representative.id
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq representative.phone
  end
end
