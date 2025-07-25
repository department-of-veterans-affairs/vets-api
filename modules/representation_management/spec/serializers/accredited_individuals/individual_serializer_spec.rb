# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::AccreditedIndividuals::IndividualSerializer, type: :serializer do
  subject { described_class.new(individual) }

  before do
    create(:accredited_individual,
           :with_organizations,
           individual_type: 'representative',
           registration_number: '123abc',
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
           phone: '222-222-2222',
           email: 'email@example.com',
           lat: '39',
           long: '-75')
  end

  let(:individual) do
    AccreditedIndividual
      .includes(:accredited_organizations)
      .where(registration_number: '123abc')
      .select('accredited_individuals.*, 4023.36 as distance')
      .first
  end
  let(:data) { subject.serializable_hash.with_indifferent_access['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq(individual.id)
  end

  it 'includes individual_type' do
    expect(attributes['individual_type']).to eq('representative')
  end

  it 'includes registration_number' do
    expect(attributes['registration_number']).to eq('123abc')
  end

  it 'includes first_name' do
    expect(attributes['first_name']).to eq('Bob')
  end

  it 'includes last_name' do
    expect(attributes['last_name']).to eq('Law')
  end

  it 'includes address_line1' do
    expect(attributes['address_line1']).to eq('123 East Main St')
  end

  it 'includes address_line2' do
    expect(attributes['address_line2']).to eq('Suite 1')
  end

  it 'includes address_line3' do
    expect(attributes['address_line3']).to eq('Address Line 3')
  end

  it 'includes address_type' do
    expect(attributes['address_type']).to eq('DOMESTIC')
  end

  it 'includes city' do
    expect(attributes['city']).to eq('My City')
  end

  it 'includes country_name' do
    expect(attributes['country_name']).to eq('United States of America')
  end

  it 'includes country_code_iso3' do
    expect(attributes['country_code_iso3']).to eq('USA')
  end

  it 'includes province' do
    expect(attributes['province']).to eq('A Province')
  end

  it 'includes international_postal_code' do
    expect(attributes['international_postal_code']).to eq('12345')
  end

  it 'includes state_code' do
    expect(attributes['state_code']).to eq('ZZ')
  end

  it 'includes zip_code' do
    expect(attributes['zip_code']).to eq('12345')
  end

  it 'includes zip_suffix' do
    expect(attributes['zip_suffix']).to eq('6789')
  end

  it 'includes phone' do
    expect(attributes['phone']).to eq('222-222-2222')
  end

  it 'includes email' do
    expect(attributes['email']).to eq('email@example.com')
  end

  it 'includes lat' do
    expect(attributes['lat']).to eq(39)
  end

  it 'includes long' do
    expect(attributes['long']).to eq(-75)
  end

  it 'includes full_name' do
    expect(attributes['full_name']).to eq('Bob Law')
  end

  it 'includes distance' do
    expect(attributes['distance']).to eq(2.5)
  end

  it 'includes accredited_organizations' do
    expect(attributes['accredited_organizations']).not_to be_nil
  end
end
