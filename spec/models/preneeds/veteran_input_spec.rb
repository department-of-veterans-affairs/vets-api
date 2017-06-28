# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::VeteranInput do
  subject { described_class.new(params) }

  let(:params) { attributes_for :veteran_input }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires a current_name' do
      params.delete(:current_name)
      expect(subject).to_not be_valid
    end

    it 'requires a properly formated date_of_birth' do
      params[:date_of_birth] = '11/11/11'
      expect(subject).to_not be_valid
    end

    it 'requires a properly formated date_of_death' do
      params[:date_of_death] = '11/11/11'
      expect(subject).to_not be_valid
    end

    it 'requires a gender' do
      params.delete(:gender)
      expect(subject).to_not be_valid
    end

    it 'requires a valid gender' do
      params[:gender] = 'Bison'
      expect(subject).to_not be_valid
    end

    it 'requires a is_deceased' do
      params.delete(:is_deceased)
      expect(subject).to_not be_valid
    end

    it 'requires a valid is_deceased' do
      params[:is_deceased] = 'if I every get my hands on him ...'
      expect(subject).to_not be_valid
    end

    it 'requires a marital_status' do
      params.delete(:marital_status)
      expect(subject).to_not be_valid
    end

    it 'requires a valid marital_status' do
      params[:marital_status] = 'Thrice ...'
      expect(subject).to_not be_valid
    end

    it 'requires a valid military_service_number' do
      params[:military_service_number] = '1' * 10
      expect(subject).to_not be_valid
    end

    it 'requires a valid place_of_birth' do
      params[:place_of_birth] = 'NY' * 101
      expect(subject).to_not be_valid
    end

    it 'requires a service_name' do
      params.delete(:service_name)
      expect(subject).to_not be_valid
    end

    it 'requires service_records' do
      params[:service_records] = []
      expect(subject).to_not be_valid
    end

    it 'requires an ssn' do
      params.delete(:ssn)
      expect(subject).to_not be_valid
    end

    it 'requires an ssn to have a valid format' do
      params[:ssn] = '123456789'
      expect(subject).to_not be_valid
    end

    it 'requires a valid va_claim_number' do
      params[:va_claim_number] = '1' * 10
      expect(subject).to_not be_valid
    end

    it 'requires a military_status' do
      params.delete(:military_status)
      expect(subject).to_not be_valid
    end

    it 'requires military_status to have a valid format' do
      params[:military_status] = 'ZZ Plural Z-alpha'
      expect(subject).to_not be_valid
    end
  end
end
