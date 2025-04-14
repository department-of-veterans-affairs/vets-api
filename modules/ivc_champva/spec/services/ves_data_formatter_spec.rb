# frozen_string_literal: true

require 'rails_helper'

describe IvcChampva::VesDataFormatter do
  let(:valid_data) do
    {
      applicationType: 'CHAMPVA_APPLICATION',
      applicationUUID: '12345678-1234-5678-1234-567812345678',
      sponsor: {
        personUUID: '12345678-1234-5678-1234-567812345678',
        firstName: 'Joe',
        lastName: 'Johnson',
        middleInitial: 'X',
        ssn: '123123123',
        vaFileNumber: '',
        dateOfBirth: '1999-01-01',
        dateOfMarriage: '',
        isDeceased: false,
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
          personUUID: '12345678-1234-5678-1234-567812345678',
          firstName: 'Johnny',
          lastName: 'Alvin',
          middleInitial: 'T',
          ssn: '345345345',
          emailAddress: 'johnny@alvin.gov',
          phoneNumber: '5555551234',
          gender: 'MALE',
          enrolledInMedicare: true,
          hasOtherInsurance: true,
          relationshipToSponsor: 'CHILD',
          childtype: 'ADOPTED',
          dateOfBirth: '2000-01-01',
          address: {
            streetAddress: '456 Circle Street ',
            city: 'Clinton',
            state: 'AS',
            zipCode: '56790'
          }
        }
      ],
      certification: {
        signature: 'certifier jones',
        signatureDate: '1999-01-01',
        firstName: 'Certifier',
        lastName: 'Jones',
        middleInitial: 'X',
        phoneNumber: '1231231234'
      },
      transactionUUID: '12345678-1234-5678-1234-567812345678'
    }
  end

  let(:parsed_form_data) do
    {
      'veteran' => {
        'full_name' => { 'first' => 'Joe', 'last' => 'Johnson', 'middle' => 'X' },
        'ssn_or_tin' => '123123123',
        'va_claim_number' => '',
        'date_of_birth' => '1999-01-01',
        'phone_number' => '',
        'address' => {
          'street_combined' => '123 Certifier Street ',
          'city' => 'Citytown',
          'state' => 'AL',
          'postal_code' => '12312'
        },
        'sponsor_is_deceased' => false,
        'is_active_service_death' => false,
        'date_of_marriage' => '',
        'sponsor_address' => {
          'country' => 'USA',
          'street' => '456 Circle Street',
          'city' => 'Clinton',
          'state' => 'AS',
          'postal_code' => '56790',
          'street_combined' => '456 Circle Street '
        }
      },
      'applicants' => [
        {
          'applicant_email_address' => 'johnny@alvin.gov',
          'applicant_address' => {
            'country' => 'USA',
            'street' => '456 Circle Street',
            'city' => 'Clinton',
            'state' => 'AS',
            'postal_code' => '56790',
            'street_combined' => '456 Circle Street '
          },
          'applicant_ssn' => { 'ssn' => '345345345' },
          'applicant_phone' => '5555551234',
          'applicant_gender' => { 'gender' => 'MALE' },
          'applicant_dob' => '2000-01-01',
          'applicant_name' => { 'first' => 'Johnny', 'middle' => 'T', 'last' => 'Alvin' },
          'applicant_medicare_status' => { 'eligibility' => 'enrolled' },
          'applicant_has_ohi' => { 'has_ohi' => 'yes' },
          'ssn_or_tin' => '345345345',
          'vet_relationship' => 'CHILD',
          'childtype' => { 'relationship_to_veteran' => 'ADOPTED' },
          'applicant_supporting_documents' => []
        }
      ],
      'certification' => {
        'date' => '1999-01-01',
        'last_name' => 'Jones',
        'middle_initial' => 'X',
        'first_name' => 'Certifier',
        'phone_number' => '1231231234'
      },
      'statement_of_truth_signature' => 'certifier jones'
    }
  end

  # Create a fresh deep copy before each test
  before do
    # Deep copy the object using Marshal
    @request_body = Marshal.load(Marshal.dump(valid_data))
    @parsed_form_data_copy = Marshal.load(Marshal.dump(parsed_form_data))

    # Mock SecureRandom.uuid to return expected values
    allow(SecureRandom).to receive(:uuid).and_return('12345678-1234-5678-1234-567812345678')
  end

  describe 'data is valid' do
    it 'maintains all the original keys/values after validating' do
      validated_data = IvcChampva::VesDataFormatter.format_for_request(parsed_form_data)

      # Check that all the original keys/values present in @request_body
      # are still present in the formatted object.
      h1 = JSON.parse(@request_body.to_json).sort.to_h
      h2 = JSON.parse(validated_data.to_json).sort.to_h
      # Get the intersection and verify h2 contained all original keys
      h3 = h1.slice(*h2.keys)
      expect(h3.to_json).to eq(h1.to_json)
    end
  end

  describe 'ves_request to_json' do
    it 'returns json' do
      ves_request = IvcChampva::VesDataFormatter.format_for_request(parsed_form_data)

      expect(ves_request.to_json).to be_a(String)
    end
  end

  describe 'request_body key has a missing value' do
    it 'raises a missing exception' do
      expect do
        IvcChampva::VesDataFormatter.validate_presence_and_stringiness(nil, 'sponsor first name')
      end.to raise_error(ArgumentError, 'sponsor first name is missing')
    end
  end

  describe 'string key has a non-string value' do
    it 'raises a non-string exception' do
      expect do
        IvcChampva::VesDataFormatter.validate_presence_and_stringiness(12, 'sponsor first name')
      end.to raise_error(ArgumentError, 'sponsor first name is not a string')
    end
  end

  describe 'sponsor first name is malformed' do
    describe 'contains disallowed characters' do
      it 'returns data with disallowed characters of sponsor first name stripped or corrected' do
        @parsed_form_data_copy['veteran']['full_name']['first'] = '2Jöhn~! - Jo/hn?\\'
        expected_sponsor_name = 'John - Jo/hn'

        ves_request = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)

        expect(ves_request.sponsor.first_name).to eq expected_sponsor_name
      end
    end
  end

  describe 'sponsor last name is malformed' do
    describe 'contains disallowed characters' do
      it 'returns data with disallowed characters of sponsor last name stripped or corrected' do
        @parsed_form_data_copy['veteran']['full_name']['last'] = '2Jöhnşon~!\\'
        expected_sponsor_name = 'Johnson'

        ves_request = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)

        expect(ves_request.sponsor.last_name).to eq expected_sponsor_name
      end
    end
  end

  describe 'sponsor address' do
    it 'raises an error when address is missing' do
      @parsed_form_data_copy['veteran']['address'] = nil

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError, 'sponsor address is missing')
    end

    it 'raises an error when values are empty strings' do
      # Drop the address prop from sponsor
      @parsed_form_data_copy['veteran']['address'] = {
        'street_combined' => '',
        'city' => '',
        'state' => '',
        'postal_code' => ''
      }

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError, 'sponsor city is an empty string')
    end

    it 'raises an error when address keys are missing' do
      # Drop the state from sponsor address prop
      @parsed_form_data_copy['veteran']['address'] = {
        'street_combined' => 'street',
        'city' => 'city',
        'postal_code' => '12312'
      }

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError, 'sponsor state is missing')
    end

    it 'raises an error when deceased sponsor date of death is missing' do
      @parsed_form_data_copy['veteran']['is_deceased'] = true
      @parsed_form_data_copy['veteran']['date_of_death'] = nil

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError, 'date of death is missing')
    end

    it 'adds a default address when sponsor is deceased' do
      @parsed_form_data_copy['veteran']['address'] = nil
      @parsed_form_data_copy['veteran']['is_deceased'] = true
      @parsed_form_data_copy['veteran']['date_of_death'] = '2020-01-01'

      res = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      expect(res.sponsor.address.street_address).to eq('NA')
      expect(res.sponsor.address.state).to eq('NA')
      expect(res.sponsor.address.city).to eq('NA')
      expect(res.sponsor.address.zip_code).to eq('NA')
    end

    it 'adds a default phone when sponsor is deceased' do
      @parsed_form_data_copy['veteran']['is_deceased'] = true
      @parsed_form_data_copy['veteran']['date_of_death'] = '2020-01-01'
      @parsed_form_data_copy['veteran']['phone_number'] = nil

      res = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      expect(res.sponsor.phone_number).to eq('0000000000')
    end
  end

  describe 'sponsor date of birth' do
    it 'when formatted as MM-DD-YYYY, it reformats to YYYY-MM-DD' do
      @parsed_form_data_copy['veteran']['date_of_birth'] = '01-01-2020'

      res = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)

      expect(res.sponsor.date_of_birth).to eq('2020-01-01')
    end
  end

  describe 'sponsor date of marriage' do
    it 'when formatted as MM-DD-YYYY, it reformats to YYYY-MM-DD' do
      @parsed_form_data_copy['veteran']['date_of_marriage'] = '01-01-2020'

      res = IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)

      expect(res.sponsor.date_of_marriage).to eq('2020-01-01')
    end
  end

  describe 'social security number is malformed' do
    describe 'too long' do
      it 'raises an exception' do
        @parsed_form_data_copy['veteran']['ssn_or_tin'] = '1234567890'

        expect do
          IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
        end.to raise_error(ArgumentError, 'ssn is invalid. Must be 9 digits (see regex for more detail)')
      end
    end
  end

  describe 'application UUID is not 36 chars long' do
    it 'raises an exception' do
      ves_data = IvcChampva::VesDataFormatter.transform_to_ves_format(@parsed_form_data_copy)
      ves_data[:application_uuid] = '123'

      expect do
        IvcChampva::VesDataFormatter.validate_application_uuid(ves_data)
      end.to raise_error(ArgumentError, 'application UUID is invalid. Must be 36 characters')
    end
  end

  describe 'beneficiary relationship to sponsor not in accepted values' do
    it 'raises an exception' do
      possible_values = IvcChampva::VesDataFormatter::RELATIONSHIPS.join(', ')
      @parsed_form_data_copy['applicants'][0]['vet_relationship'] = 'INVALID'

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError,
                         "Relationship INVALID is invalid. Must be in #{possible_values}")
    end
  end

  describe 'beneficiary childtype not in accepted values' do
    it 'raises an exception' do
      possible_values = IvcChampva::VesDataFormatter::CHILDTYPES.join(', ')
      @parsed_form_data_copy['applicants'][0]['childtype']['relationship_to_veteran'] = 'INVALID'

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError,
                         "beneficiary childtype is invalid. Must be in #{possible_values}")
    end
  end

  describe 'beneficiary gender not in accepted values' do
    it 'raises an exception' do
      possible_values = IvcChampva::VesDataFormatter::GENDERS.join(', ')
      @parsed_form_data_copy['applicants'][0]['applicant_gender']['gender'] = 'INVALID'

      expect do
        IvcChampva::VesDataFormatter.format_for_request(@parsed_form_data_copy)
      end.to raise_error(ArgumentError,
                         "beneficiary gender is invalid. Must be in #{possible_values}")
    end
  end

  describe 'phone number is malformed' do
    it 'removes non-numeric characters' do
      phone = '+1 (123) 123-1234'

      expect(IvcChampva::VesDataFormatter.format_phone_number(phone)).to eq('11231231234')
    end

    it 'raises an exception when phone number is not at least 10 digits' do
      phone = { phone_number: '123456789' } # 9 digits

      expect do
        IvcChampva::VesDataFormatter.validate_phone(phone, 'phone number')
      end.to raise_error(ArgumentError, 'phone number is invalid. See regex for more detail')

      phone = { phone_number: '1231231234' } # 10 digits

      expect(IvcChampva::VesDataFormatter.validate_phone(phone, 'phone number')).to eq(phone)

      phone = { phone_number: '11231231234' } # 11 digits

      expect(IvcChampva::VesDataFormatter.validate_phone(phone, 'phone number')).to eq(phone)
    end
  end
end
