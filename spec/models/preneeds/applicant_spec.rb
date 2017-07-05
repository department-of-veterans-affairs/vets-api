# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::Applicant do
  subject { described_class.new(params) }
  let(:params) { attributes_for :applicant }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires an applicant_email' do
      params.delete(:applicant_email)
      expect(subject).to_not be_valid
    end

    it 'requires applicant_email to have a valid format' do
      params[:applicant_email] = 'x@123456789'
      expect(subject).to_not be_valid
    end

    it 'requires an applicant_phone_number' do
      params.delete(:applicant_phone_number)
      expect(subject).to_not be_valid
    end

    it 'requires applicant_phone_number to have a valid format' do
      params[:applicant_phone_number] = '123(345)2121'
      expect(subject).to_not be_valid
    end

    it 'requires an applicant_relationship_to_claimant' do
      params.delete(:applicant_relationship_to_claimant)
      expect(subject).to_not be_valid
    end

    it 'requires an applicant_relationship_to_claimant to have a valid value' do
      params[:applicant_relationship_to_claimant] = 'blah-blah'
      expect(subject).to_not be_valid
    end

    it 'requires a completing_reason' do
      params.delete(:completing_reason)
      expect(subject).to_not be_valid
    end

    it 'requires a completing_reason to be less than 257 characters' do
      params[:completing_reason] = 'a' * 257
      expect(subject).to_not be_valid
    end

    it 'requires a mailing_address' do
      params.delete(:mailing_address)
      expect(subject).to_not be_valid
    end

    it 'requires a valid mailing_address' do
      params[:mailing_address][:address1] = nil
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
  end
end
