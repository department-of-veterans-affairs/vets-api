# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Create::FormDataAdapter do
  describe '#call' do
    subject { described_class.new(data:, dependent:, service_branch:) }

    let(:dependent) { true }
    let(:service_branch) { 'ARMY' }
    let(:data) do
      {
        record_consent: true,
        consent_limits: ['HIV'],
        consent_address_change: true,
        veteran_first_name: 'John',
        veteran_middle_initial: 'M',
        veteran_last_name: 'Veteran',
        veteran_social_security_number: '123456789',
        veteran_va_file_number: '987654321',
        veteran_date_of_birth: '1980-12-31',
        veteran_service_number: '123123123',
        veteran_address_line1: '123 Fake Veteran St',
        veteran_address_line2: 'Apt 1',
        veteran_city: 'Portland',
        veteran_state_code: 'OR',
        veteran_country: 'US',
        veteran_zip_code: '12345',
        veteran_zip_code_suffix: '6789',
        veteran_phone: '555-555-5555',
        veteran_email: 'veteran@example.com',
        claimant_first_name: 'Bob',
        claimant_middle_initial: 'E',
        claimant_last_name: 'Claimant',
        claimant_date_of_birth: '1981-12-31',
        claimant_relationship: 'Spouse',
        claimant_address_line1: '123 Fake Claimant St',
        claimant_address_line2: 'Apt 2',
        claimant_city: 'Eugene',
        claimant_state_code: 'OR',
        claimant_country: 'US',
        claimant_zip_code: '54321',
        claimant_zip_code_suffix: '9876',
        claimant_phone: '222-555-5555',
        claimant_email: 'claimant@example.com'
      }
    end

    it 'fully adapts the data' do
      expected_result = {
        data: {
          'authorizations' => {
            'recordDisclosure' => true,
            'recordDisclosureLimitations' => ['HIV'],
            'addressChange' => true
          },
          'dependent' => {
            'name' => {
              'first' => 'Bob',
              'middle' => 'E',
              'last' => 'Claimant'
            },
            'address' => {
              'addressLine1' => '123 Fake Claimant St',
              'addressLine2' => 'Apt 2',
              'city' => 'Eugene',
              'stateCode' => 'OR',
              'country' => 'US',
              'zipCode' => '54321',
              'zipCodeSuffix' => '9876'
            },
            'dateOfBirth' => '1981-12-31',
            'relationship' => 'Spouse',
            'phone' => '2225555555',
            'email' => 'claimant@example.com'
          },
          'veteran' => {
            'name' => {
              'first' => 'John',
              'middle' => 'M',
              'last' => 'Veteran'
            },
            'address' => {
              'addressLine1' => '123 Fake Veteran St',
              'addressLine2' => 'Apt 1',
              'city' => 'Portland',
              'stateCode' => 'OR',
              'country' => 'US',
              'zipCode' => '12345',
              'zipCodeSuffix' => '6789'
            },
            'ssn' => '123456789',
            'vaFileNumber' => '987654321',
            'dateOfBirth' => '1980-12-31',
            'serviceNumber' => '123123123',
            'serviceBranch' => 'ARMY',
            'phone' => '5555555555',
            'email' => 'veteran@example.com'
          }
        },
        errors: []
      }

      expect(subject.call).to eq(expected_result)
    end

    context 'when there is no dependent' do
      let(:dependent) { false }

      it 'sets the dependent to nil' do
        expect(subject.call[:data]['dependent']).to be_nil

        expect(subject.call[:errors]).to eq([])
      end
    end

    context 'when there is no service branch' do
      let(:service_branch) { nil }

      it 'sets serviceBranch to nil' do
        expect(subject.call[:data]['serviceBranch']).to be_nil

        expect(subject.call[:errors]).to eq([])
      end
    end

    context 'when consent limits is empty' do
      it 'sets recordDisclosureLimitations to an empty array' do
        data[:consent_limits] = []

        expect(subject.call[:data]['authorizations']['recordDisclosureLimitations']).to eq([])
        expect(subject.call[:errors]).to eq([])
      end
    end

    context 'when an attribute is an empty string' do
      it 'sets the value to nil' do
        data[:claimant_address_line2] = ''

        expect(subject.call[:data]['dependent']['addressLine2']).to be_nil
        expect(subject.call[:errors]).to eq([])
      end
    end

    context 'when there is an error with validation' do
      it 'adds the error message to the errors attribute' do
        data[:consent_limits] = ['abc']
        data.delete(:veteran_address_line1)

        expected_error = [
          'value at `/authorizations/recordDisclosureLimitations/0` is not one of: ' \
          '["ALCOHOLISM", "DRUG_ABUSE", "HIV", "SICKLE_CELL"]',
          'value at `/veteran/address/addressLine1` is not a string'
        ]
        expect(subject.call[:errors]).to eq(expected_error)
      end
    end

    describe '#sanitize_phone_number' do
      it 'removes all non-digit characters' do
        expect(subject.send(:sanitize_phone_number, '(555) 123-4567')).to eq('5551234567')
        expect(subject.send(:sanitize_phone_number, '555.987.6543')).to eq('5559876543')
        expect(subject.send(:sanitize_phone_number, '555-555-5555')).to eq('5555555555')
      end

      it 'returns digits unchanged' do
        expect(subject.send(:sanitize_phone_number, '1234567890')).to eq('1234567890')
      end

      it 'returns nil string if input has no digits' do
        expect(subject.send(:sanitize_phone_number, 'abc-def')).to be_nil
      end
    end
  end
end
