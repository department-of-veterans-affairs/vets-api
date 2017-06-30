# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::AddressInput do
  subject { described_class.new(params) }
  let(:params) { attributes_for :address_input }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires an address' do
      params.delete(:address1)
      expect(subject).to_not be_valid
    end

    it 'requires a city' do
      params.delete(:city)
      expect(subject).to_not be_valid
    end

    it 'requires a country' do
      params.delete(:country_code)
      expect(subject).to_not be_valid
    end

    it 'state must be 2 or 3 characters' do
      params[:state] = 'a' * 4
      expect(subject).to_not be_valid
    end

    it 'address1 must be less than 36 characters' do
      params[:address1] = 'a' * 36
      expect(subject).to_not be_valid
    end

    it 'address2 must be less than 36 characters' do
      params[:address2] = 'a' * 36
      expect(subject).to_not be_valid
    end

    it 'address3 must be less than 36 characters' do
      params[:address3] = 'a' * 36
      expect(subject).to_not be_valid
    end

    it 'city must be less than 31 characters' do
      params[:city] = 'a' * 31
      expect(subject).to_not be_valid
    end

    it 'state must be less than 4 characters' do
      params[:state] = 'a' * 4
      expect(subject).to_not be_valid
    end

    it 'country_code must be in a predefined list' do
      params[:country_code] = 'a!'
      expect(subject).to_not be_valid
    end

    it 'postal_zip must be exactly 5 characters' do
      params[:postal_zip] = '1' * 6
      expect(subject).to_not be_valid
    end
  end
end
