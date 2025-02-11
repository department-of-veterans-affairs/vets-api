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

  describe '.authorize_vso_representative!' do
    let(:email) { 'rep1@vso.org' }
    let(:icn) { 'test-icn-123' }

    let!(:matching_email_record) do
      create(:user_account_accredited_individual,
             user_account_email: email,
             user_account_icn: nil,
             accredited_individual_registration_number: 'REG001')
    end

    let!(:matching_icn_record) do
      create(:user_account_accredited_individual,
             user_account_email: 'other@vso.org',
             user_account_icn: icn,
             accredited_individual_registration_number: 'REG002')
    end

    let!(:unrelated_record) do
      create(:user_account_accredited_individual,
             user_account_email: 'unrelated@vso.org',
             user_account_icn: 'other-icn',
             accredited_individual_registration_number: 'REG003')
    end

    it 'assigns ICN to records with matching email' do
      described_class.authorize_vso_representative!(email: email, icn: icn)
      expect(matching_email_record.reload.user_account_icn).to eq(icn)
    end

    it 'removes ICN from records with matching ICN but different email' do
      described_class.authorize_vso_representative!(email: email, icn: icn)
      expect(matching_icn_record.reload.user_account_icn).to be_nil
    end

    it 'returns registration numbers only for records with matching email' do
      result = described_class.authorize_vso_representative!(email: email, icn: icn)
      expect(result).to contain_exactly('REG001')
    end

    it 'does not modify unrelated records' do
      described_class.authorize_vso_representative!(email: email, icn: icn)
      expect(unrelated_record.reload.user_account_icn).to eq('other-icn')
    end

    context 'when record fails validation' do
      before do
        allow_any_instance_of(described_class).to receive(:save).and_return(false)
      end

      it 'does not return registration number for failed saves' do
        result = described_class.authorize_vso_representative!(email: email, icn: icn)
        expect(result).to be_empty
      end
    end
  end
end
