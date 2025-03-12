# frozen_string_literal: true

require 'rails_helper'

valid_data = {
  applicationType: 'CHAMPVA Application',
  applicationUUID: '12345678-1234-5678-1234-567812345678',
  sponsor: {
    personUUID: '52345678-1234-5678-1234-567812345678',
    firstName: 'Joe',
    lastName: 'Johnson',
    middleInitial: 'X',
    ssn: '123123123',
    vaFileNumber: '',
    dateOfBirth: '1999-01-01',
    dateOfMarriage: '',
    isDeceased: true,
    dateOfDeath: '1999-01-01',
    isDeathOnActiveService: false,
    address: {
      streetAddress: '123 Certifier Street ',
      city: 'Citytown',
      state: 'AL',
      zipCode: '12312'
    }
  },
  beneficiaries: [
    {
      personUUID: '62345678-1234-5678-1234-567812345678',
      firstName: 'Johnny',
      lastName: 'Alvin',
      middleInitial: 'T',
      ssn: '345345345',
      emailAddress: 'johnny@alvin.gov',
      phoneNumber: '+1 (555) 555-1234',
      gender: 'MALE',
      enrolledInMedicare: true,
      hasOtherInsurance: true,
      relationshipToSponsor: 'CHILD',
      childtype: 'ADOPTED',
      address: {
        streetAddress: '456 Circle Street ',
        city: 'Clinton',
        state: 'AS',
        zipCode: '56790'
      },
      dateOfBirth: '2000-01-01'
    }
  ],
  certification: {
    signature: 'certifier jones',
    signatureDate: '1999-01-01',
    firstName: 'Certifier',
    lastName: 'Jones',
    middleInitial: 'X',
    phoneNumber: '(123) 123-1234'
  }
}

describe IvcChampva::VesDataValidator do
  describe 'data is valid' do
    it 'returns unmodified data' do
      # Deep copy our properly formatted data
      request_body = Marshal.load(Marshal.dump(valid_data))

      validated_data = IvcChampva::VesDataValidator.validate(request_body)

      expect(validated_data).to eq(request_body)
    end
  end

  describe 'request_body key has a missing value' do
    it 'raises a missing exception' do
      expect do
        IvcChampva::VesDataValidator.validate_presence_and_stringiness(nil, 'sponsor first name')
      end.to raise_error(ArgumentError, 'sponsor first name is missing')
    end
  end

  describe 'string key has a non-string value' do
    it 'raises a non-string exception' do
      expect do
        IvcChampva::VesDataValidator.validate_presence_and_stringiness(12, 'sponsor first name')
      end.to raise_error(ArgumentError, 'sponsor first name is not a string')
    end
  end

  describe 'sponsor first name is malformed' do
    describe 'contains disallowed characters' do
      it 'returns data with disallowed characters of sponsor first name stripped or corrected' do
        # Deep copy our valid data
        request_body = Marshal.load(Marshal.dump(valid_data))
        request_body[:sponsor][:firstName] = '2Jöhn~! - Jo/hn?\\'
        expected_sponsor_name = 'John - Jo/hn'

        validated_data = IvcChampva::VesDataValidator.validate(request_body)

        expect(validated_data[:sponsor][:firstName]).to eq expected_sponsor_name
      end
    end
  end

  describe 'sponsor last name is malformed' do
    describe 'contains disallowed characters' do
      it 'returns data with disallowed characters of sponsor last name stripped or corrected' do
        # Deep copy our valid data
        request_body = Marshal.load(Marshal.dump(valid_data))
        request_body[:sponsor][:lastName] = '2Jöhnşon~!\\'
        expected_sponsor_name = 'Johnson'

        validated_data = IvcChampva::VesDataValidator.validate(request_body)

        expect(validated_data[:sponsor][:lastName]).to eq expected_sponsor_name
      end
    end
  end

  describe 'social security number is malformed' do
    describe 'too long' do
      it 'raises an exception' do
        # Deep copy our valid data
        request_body = Marshal.load(Marshal.dump(valid_data))
        request_body[:sponsor][:ssn] = '1234567890'

        expect do
          IvcChampva::VesDataValidator.validate(request_body)
        end.to raise_error(ArgumentError, 'ssn is invalid. Must be 9 digits (see regex for more detail)')
      end
    end
  end
end
