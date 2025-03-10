# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::UserAccountAccreditedIndividual, type: :model do
  let(:valid_attributes) do
    {
      accredited_individual_registration_number: 'REG001',
      power_of_attorney_holder_type: 'veteran_service_organization',
      user_account_email: 'rep1@vso.org',
      user_account_icn: 'ICN001'
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

  describe '.for_user_account_email' do
    let!(:existing_record) do
      described_class.create!(
        accredited_individual_registration_number: 'REG002',
        power_of_attorney_holder_type: 'veteran_service_organization',
        user_account_email: 'rep1@vso.org',
        user_account_icn: 'ICN001'
      )
    end

    context 'when a matching record exists by email' do
      it 'updates the record and returns it' do
        result = described_class.for_user_account_email(
          'rep1@vso.org', user_account_icn: 'ICN_NEW'
        )

        expect(result.first).to eq(existing_record.reload)
        # Ensures the ICN was updated
        expect(result.first.user_account_icn).to eq('ICN_NEW')
      end
    end

    context 'when a matching record exists by ICN' do
      it 'updates the record and returns it' do
        result = described_class.for_user_account_email(
          'new_email@vso.org', user_account_icn: 'ICN001'
        )

        # returns [] but updates the matching record icn to nil
        expect(result).to be_empty
        expect(described_class.first.user_account_icn).to be_nil
      end
    end

    context 'when no matching record exists' do
      it 'does not create a new record' do
        expect do
          described_class.for_user_account_email(
            'new_user@vso.org', user_account_icn: 'ICN_NEW'
          )
        end.not_to(change(described_class, :count))

        new_record = described_class.find_by(user_account_email: 'new_user@vso.org')
        expect(new_record).to be_nil
      end
    end

    context 'when both email and ICN exist but do not match the same record' do
      let!(:conflicting_record) do
        described_class.create!(
          accredited_individual_registration_number: 'REG003',
          power_of_attorney_holder_type: 'veteran_service_organization',
          user_account_email: 'rep2@vso.org',
          user_account_icn: 'ICN002'
        )
      end

      it 'updates the correct record and does not merge incorrectly' do
        result = described_class.for_user_account_email(
          'rep2@vso.org', user_account_icn: 'ICN001'
        )

        expect(result.first).to eq(conflicting_record.reload)
        expect(result.first.user_account_icn).to eq('ICN001')
        expect(result.first.user_account_email).to eq('rep2@vso.org')
      end
    end
  end
end
