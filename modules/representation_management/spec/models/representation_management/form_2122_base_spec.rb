# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122Base, type: :model do
  describe 'validations' do
    subject { described_class.new }

    subject_with_claimant = described_class.new(claimant_first_name: 'John')

    it { expect(subject).to validate_presence_of(:veteran_first_name) }
    it { expect(subject).to validate_length_of(:veteran_first_name).is_at_most(12) }
    it { expect(subject).to validate_length_of(:veteran_middle_initial).is_at_most(1) }
    it { expect(subject).to validate_presence_of(:veteran_last_name) }
    it { expect(subject).to validate_length_of(:veteran_last_name).is_at_most(18) }
    it { expect(subject).to validate_presence_of(:veteran_social_security_number) }
    it { expect(subject).to allow_value('123456789').for(:veteran_social_security_number) }
    it { expect(subject).not_to allow_value('12345678A').for(:veteran_social_security_number) }
    it { expect(subject).not_to allow_value('12345678').for(:veteran_social_security_number) }
    it { expect(subject).not_to allow_value('1234567890').for(:veteran_social_security_number) }
    it { expect(subject).to allow_value('123456789').for(:veteran_va_file_number) }
    it { expect(subject).not_to allow_value('12345678').for(:veteran_va_file_number) }
    it { expect(subject).not_to allow_value('1234567890').for(:veteran_va_file_number) }
    it { expect(subject).to validate_presence_of(:veteran_date_of_birth) }
    it { expect(subject).to validate_presence_of(:veteran_address_line1) }
    it { expect(subject).to validate_length_of(:veteran_address_line1).is_at_most(30) }
    it { expect(subject).to validate_length_of(:veteran_address_line2).is_at_most(5) }
    it { expect(subject).to validate_presence_of(:veteran_city) }
    it { expect(subject).to validate_length_of(:veteran_city).is_at_most(18) }
    it { expect(subject).to validate_presence_of(:veteran_country) }
    it { expect(subject).to validate_length_of(:veteran_country).is_equal_to(2) }
    it { expect(subject).to validate_presence_of(:veteran_state_code) }
    it { expect(subject).to validate_length_of(:veteran_state_code).is_equal_to(2) }
    it { expect(subject).to validate_presence_of(:veteran_zip_code) }
    it { expect(subject).to validate_length_of(:veteran_zip_code).is_equal_to(5) }
    it { expect(subject).to allow_value('12345').for(:veteran_zip_code) }
    it { expect(subject).not_to allow_value('1234A').for(:veteran_zip_code) }
    it { expect(subject).not_to allow_value('12345').for(:veteran_zip_code_suffix) }
    it { expect(subject).to allow_value('1234').for(:veteran_zip_code_suffix) }
    it { expect(subject).to allow_value('').for(:veteran_zip_code_suffix) }
    it { expect(subject).to validate_length_of(:veteran_zip_code_suffix).is_equal_to(4) }
    it { expect(subject).to allow_value('1234567890').for(:veteran_phone) }
    it { expect(subject).not_to allow_value('123456789A').for(:veteran_phone) }
    it { expect(subject).not_to allow_value('123456789').for(:veteran_phone) }
    it { expect(subject).to allow_value('123456789').for(:veteran_service_number) }
    it { expect(subject).not_to allow_value('12345678').for(:veteran_service_number) }
    it { expect(subject).not_to allow_value('1234567890').for(:veteran_service_number) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_first_name).is_at_most(12) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_last_name) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_last_name).is_at_most(18) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_date_of_birth) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_relationship) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_address_line1) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_address_line1).is_at_most(30) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_address_line2).is_at_most(5) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_city) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_city).is_at_most(18) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_country) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_country).is_equal_to(2) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_state_code) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_state_code).is_equal_to(2) }
    it { expect(subject_with_claimant).to validate_presence_of(:claimant_zip_code) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_zip_code).is_equal_to(5) }
    it { expect(subject_with_claimant).to allow_value('12345').for(:claimant_zip_code) }
    it { expect(subject_with_claimant).not_to allow_value('1234A').for(:claimant_zip_code) }
    it { expect(subject_with_claimant).not_to allow_value('12345').for(:claimant_zip_code_suffix) }
    it { expect(subject_with_claimant).to allow_value('1234').for(:claimant_zip_code_suffix) }
    it { expect(subject_with_claimant).to allow_value('').for(:claimant_zip_code_suffix) }
    it { expect(subject_with_claimant).to validate_length_of(:claimant_zip_code_suffix).is_equal_to(4) }
    it { expect(subject_with_claimant).to allow_value('1234567890').for(:claimant_phone) }
    it { expect(subject_with_claimant).not_to allow_value('123456789A').for(:claimant_phone) }
    it { expect(subject_with_claimant).not_to allow_value('123456789').for(:claimant_phone) }

    # Custom validation tests
    context 'consent_limits_must_contain_valid_values' do
      it 'is not valid if consent_limits contains invalid values' do
        subject.consent_limits = ['alcolholism'] # Not fully capitalized
        subject.send(:consent_limits_must_contain_valid_values)
        expect(subject.errors[:consent_limits].first).to include('is not a valid limitation of consent')
      end

      it 'is not valid if there are a mix of valid and invalid values' do
        subject.consent_limits = %w[ALCOHOLISM drug_abuse] # Not fully capitalized
        subject.send(:consent_limits_must_contain_valid_values)
        expect(subject.errors[:consent_limits].first).to include('is not a valid limitation of consent')
      end

      it 'is valid if consent_limits contains valid values' do
        subject.consent_limits = ['ALCOHOLISM']
        subject.send(:consent_limits_must_contain_valid_values)
        expect(subject.errors[:consent_limits]).to be_empty
      end

      it 'is valid if multiple valid values are present' do
        subject.consent_limits = %w[ALCOHOLISM DRUG_ABUSE]
        subject.send(:consent_limits_must_contain_valid_values)
        expect(subject.errors[:consent_limits]).to be_empty
      end
    end
  end
end
