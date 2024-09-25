# frozen_string_literal: true

require 'rails_helper'
require 'vets/model'

RSpec.describe Vets::Model do
  class Apartment < Vets::Model
    attribute :unit_number, Integer
    attribute :building_number, Integer
  end

  class Address < Vets::Model
    attribute :street, String
    attribute :street2, String
    attribute :city, String
    attribute :country, String
    attribute :state, String
    attribute :postal_code, String
    attribute :apartment, Apartment
  end

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
  let(:address) { Address.new(address_params) }
  let(:apartment) { Apartment.new(apartment_params) }

  describe '.attributes' do
    it 'returns a hash of the attribute parameters' do
      attributes = Address.attributes
      expected_attributes = {
        street: { type: String, default: nil, array: false },
        street2: { type: String, default: nil, array: false },
        city: { type: String, default: nil, array: false },
        country: { type: String, default: nil, array: false },
        state: { type: String, default: nil, array: false },
        postal_code: { type: String, default: nil, array: false },
        apartment: { type: Apartment, default: nil, array: false }
      }
      expect(attributes).to eq(expected_attributes)
    end
  end

  describe '#initialize' do
    it 'initializes the model with provided params' do
      address = Address.new(street: '456 Elm St')
      expect(address.instance_variable_get('@street')).to eq('456 Elm St')
    end

    it 'initializes the model with objects' do
      address = Address.new(apartment:)
      expect(address.instance_variable_get('@apartment')).to eq(apartment)
    end

    it 'sets missing parameters to nil' do
      expect(address.instance_variable_get('@street2')).to be_nil
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
