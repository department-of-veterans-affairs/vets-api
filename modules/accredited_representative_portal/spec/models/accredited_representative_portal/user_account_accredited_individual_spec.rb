# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::UserAccountAccreditedIndividual, type: :model do
  let(:valid_attributes) do
    {
      accredited_individual_registration_number: 'REG001',
      power_of_attorney_holder_type: 'veteran_service_organization',
      user_account_email: 'rep1@vso.org'
    }
  end

  describe 'validations' do
    subject(:model) { described_class.new(valid_attributes) }

    it { is_expected.to be_valid }

    it 'requires registration number' do
      model.accredited_individual_registration_number = nil
      expect(model).not_to be_valid
      expect(model.errors[:accredited_individual_registration_number]).to include("can't be blank")
    end

    it 'requires email' do
      model.user_account_email = nil
      expect(model).not_to be_valid
      expect(model.errors[:user_account_email]).to include("can't be blank")
    end

    it 'validates email format' do
      model.user_account_email = 'not-an-email'
      expect(model).not_to be_valid
      expect(model.errors[:user_account_email]).to include('is invalid')
    end
  end

  describe 'power_of_attorney_holder_type enum' do
    it 'defines the correct types' do
      expect(described_class.power_of_attorney_holder_types)
        .to eq('veteran_service_organization' => 'veteran_service_organization')
    end

    it 'raises ArgumentError for invalid type' do
      expect do
        described_class.new(
          power_of_attorney_holder_type: 'invalid_type',
          accredited_individual_registration_number: 'REG001'
        ).validate!
      end.to raise_error(ActiveRecord::RecordInvalid, /Power of attorney holder type is not included in the list/)
    end

    it 'provides helper methods for checking type' do
      model = described_class.new(power_of_attorney_holder_type: 'veteran_service_organization')
      expect(model).to be_veteran_service_organization
    end
  end
end
