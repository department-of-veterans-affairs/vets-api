# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::OriginalEntities::RepresentativeSerializer, type: :serializer do
  subject { described_class.new(representative) }

  let(:representative) do
    create(
      :representative,
      :vso,
      representative_id: '00001',
      poa_codes: ['ABC'],
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
      phone_number: '222-222-2222',
      email: 'email@example.com'
    )
  end
  let!(:org) { create(:organization, poa: 'ABC') }
  let(:data) { subject.serializable_hash.with_indifferent_access['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq(representative.representative_id)
  end

  it 'includes individual_type' do
    expect(attributes['individual_type']).to eq('veteran_service_officer')
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

  it 'includes accredited_organizations' do
    expect(attributes['accredited_organizations']).not_to be_nil
  end

  it 'includes all three user_types' do
    representative = create(:representative, :vso, first_name: 'Bob', last_name: 'Representative')
    attorney = create(:representative, first_name: 'Bob', last_name: 'Attorney')
    claims_agent = create(:representative, :claim_agents, first_name: 'Bob', last_name: 'Agent')

    representative_data = described_class.new(representative).serializable_hash.with_indifferent_access['data']
    attorney_data = described_class.new(attorney).serializable_hash.with_indifferent_access['data']
    claims_agent_data = described_class.new(claims_agent).serializable_hash.with_indifferent_access['data']

    expect(representative_data['attributes']['individual_type']).to eq('veteran_service_officer')
    expect(attorney_data['attributes']['individual_type']).to eq('attorney')
    expect(claims_agent_data['attributes']['individual_type']).to eq('claim_agents')
  end
end
