# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::ClaimantInput do
  subject { described_class.new(params) }

  let(:params) { attributes_for :claimant_input }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires an address' do
      params.delete(:address)
      expect(subject).to_not be_valid
    end

    it 'requires a valid address' do
      params[:address][:address1] = nil
      expect(subject).to_not be_valid
    end

    it 'requires a date_of_birth' do
      params[:desired_cemetery] = 1_000
      expect(subject).to_not be_valid
    end

    it 'requires a properly formated date_of_birth' do
      params[:date_of_birth] = '11/11/11'
      expect(subject).to_not be_valid
    end

    it 'requires a desired_cemetery' do
      params.delete(:desired_cemetery)
      expect(subject).to_not be_valid
    end

    it 'requires a valid desired_cemetery' do
      params[:desired_cemetery] = 1_000
      expect(subject).to_not be_valid
    end

    it 'requires a name' do
      params.delete(:name)
      expect(subject).to_not be_valid
    end

    it 'requires a valid name' do
      params[:name][:last_name] = nil
      expect(subject).to_not be_valid
    end

    it 'requires a email to have a valid format' do
      params[:email] = '123456789'
      expect(subject).to_not be_valid
    end

    it 'requires a phone_number to have a valid format' do
      params[:phone_number] = '123(345)2121'
      expect(subject).to_not be_valid
    end

    it 'requires an applicant_relationship_to_claimant' do
      params.delete(:relationship_to_vet)
      expect(subject).to_not be_valid
    end

    it 'requires an applicant_relationship_to_claimant to have a valid value' do
      params[:relationship_to_vet] = '9'
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
  end
end
