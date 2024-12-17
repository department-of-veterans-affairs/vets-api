# frozen_string_literal: true

require 'rails_helper'
require 'vets/model'

class FakeApartment
  include Vets::Model

  attribute :unit_number, Integer
  attribute :building_number, Integer
end

class FakeAddress
  include Vets::Model

  attribute :street, String
  attribute :street2, String
  attribute :city, String
  attribute :country, String
  attribute :state, String
  attribute :postal_code, String
  attribute :apartment, FakeApartment
end

RSpec.describe Vets::Model do
  let(:apartment_params) do
    {
      unit_number: 1,
      building_number: 2
    }
  end

  let(:address_params) do
    {
      street: '123 Main St',
      city: 'New York',
      country: 'USA',
      state: 'NY',
      postal_code: '10001',
      apartment: {
        unit_number: 1,
        building_number: 2
      }
    }
  end
  let(:address) { FakeAddress.new(address_params) }
  let(:apartment) { FakeApartment.new(apartment_params) }

  describe '#initialize' do
    it 'initializes the model with provided params' do
      address = FakeAddress.new(street: '456 Elm St')
      expect(address.instance_variable_get('@street')).to eq('456 Elm St')
    end

    it 'initializes the model with objects' do
      address = FakeAddress.new(apartment:)
      expect(address.instance_variable_get('@apartment')).to eq(apartment)
    end

    it 'defines an instance variable' do
      expect(address).to be_instance_variable_defined('@street2')
    end

    it 'sets missing parameters to nil' do
      expect(address.instance_variable_get('@street2')).to be_nil
    end

    it 'rejects unknown attributes' do
      address = FakeAddress.new(street9: '456 Elm St')
      expect(address).not_to respond_to(:street9)
    end
  end

  describe '#attributes' do
    it 'returns a hash of attributes' do
      expected_attributes = address_params.merge({ street2: nil }).deep_stringify_keys
      expect(address.attributes).to eq(expected_attributes)
    end

    it 'includes nested attributes if present' do
      expected_attributes = apartment_params.deep_stringify_keys
      expect(address.attributes['apartment']).to eq(expected_attributes)
    end
  end
end
