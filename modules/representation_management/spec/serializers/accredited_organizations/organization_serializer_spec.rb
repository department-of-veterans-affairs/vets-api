# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::AccreditedOrganizations::OrganizationSerializer, type: :serializer do
  subject { described_class.new(organization) }

  let(:data) { subject.serializable_hash.with_indifferent_access['data'] }
  let(:attributes) { data['attributes'] }

  context 'serializing AccreditedOrganization record' do
    let(:organization) do
      create(:accredited_organization,
             poa_code: '000',
             name: 'My Org',
             phone: '555-555-5555',
             city: 'My City',
             state_code: 'AL',
             zip_code: '12345',
             zip_suffix: '6789',
             can_accept_digital_poa_requests: true)
    end

    it 'includes id' do
      expect(data['id']).to eq(organization.poa_code)
    end

    it 'includes type' do
      expect(data['type']).to eq(:accredited_organization)
    end

    it 'includes poa_code' do
      expect(attributes['poa_code']).to eq('000')
    end

    it 'includes name' do
      expect(attributes['name']).to eq('My Org')
    end

    it 'includes phone' do
      expect(attributes['phone']).to eq('555-555-5555')
    end

    it 'includes city' do
      expect(attributes['city']).to eq('My City')
    end

    it 'includes state_code' do
      expect(attributes['state_code']).to eq('AL')
    end

    it 'includes zip_code' do
      expect(attributes['zip_code']).to eq('12345')
    end

    it 'includes zip_suffix' do
      expect(attributes['zip_suffix']).to eq('6789')
    end
  end

  context 'serializing AccreditedOrganizationAdapter record' do
    let(:veteran_organization) do
      create(:veteran_organization,
             poa: '999',
             name: 'My Second Org',
             phone: '555-555-5555',
             city: 'My City',
             state_code: 'WA',
             zip_code: '12345',
             zip_suffix: '6789',
             can_accept_digital_poa_requests: false)
    end
    let(:organization) { RepresentationManagement::AccreditedOrganizationAdapter.new(veteran_organization) }

    it 'includes id' do
      expect(data['id']).to eq(organization.poa_code)
    end

    it 'includes type' do
      expect(data['type']).to eq(:accredited_organization)
    end

    it 'includes poa_code' do
      expect(attributes['poa_code']).to eq('999')
    end

    it 'includes name' do
      expect(attributes['name']).to eq('My Second Org')
    end

    it 'includes phone' do
      expect(attributes['phone']).to eq('555-555-5555')
    end

    it 'includes city' do
      expect(attributes['city']).to eq('My City')
    end

    it 'includes state_code' do
      expect(attributes['state_code']).to eq('WA')
    end

    it 'includes zip_code' do
      expect(attributes['zip_code']).to eq('12345')
    end

    it 'includes zip_suffix' do
      expect(attributes['zip_suffix']).to eq('6789')
    end
  end
end
