# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesApi::Client do
  subject { described_class.new }

  describe 'headers' do
    it 'returns the right headers' do
      result = subject.headers('the_right_uuid', 'the_right_acting_user')

      expect(result[:content_type]).to eq('application/json')
      expect(result['apiKey']).to eq('fake_api_key')
      expect(result['transactionUUId']).to eq('the_right_uuid')
      expect(result['acting-user']).to eq('the_right_acting_user')
    end

    it 'returns the right headers with nil acting user' do
      result = subject.headers('the_right_uuid', nil)

      expect(result[:content_type]).to eq('application/json')
      expect(result['apiKey']).to eq('fake_api_key')
      expect(result['transactionUUId']).to eq('the_right_uuid')
      expect(result['acting-user']).to eq('')
    end
  end

  describe 'map_address_to_ves_fmt' do
    it 'converts address received from frontend into VES format' do
      address = {
        'country' => 'USA',
        'street' => '456 Circle Street',
        'city' => 'Clinton',
        'state' => 'AS',
        'postal_code' => '56790',
        'street_combined' => '456 Circle Street'
      }

      res = subject.map_address_to_ves_fmt(address)
      expect(res['streetAddress']).to eq(address['street_combined'])
      expect(res['city']).to eq(address['city'])
      expect(res['state']).to eq(address['state'])
      expect(res['zipCode']).to eq(address['postal_code'])
    end

    it 'converts address received from frontend into VES format and adds NAs for missing data' do
      address = {} # No address provided; e.g., in the case of a deceased sponsor

      res = subject.map_address_to_ves_fmt(address)
      expect(res['streetAddress']).to eq('NA')
      expect(res['city']).to eq('NA')
      expect(res['state']).to eq('NA')
      expect(res['zipCode']).to eq('NA')
    end
  end

  describe 'convert_to_champva_application' do
    subject(:result) { described_class.new.convert_to_champva_application(parsed_form_data) }

    let(:parsed_form_data) do
      {
        'veteran' => {
          'full_name' => { 'first' => 'Joe', 'last' => 'Johnson' },
          'ssn_or_tin' => '123123123',
          'va_claim_number' => '',
          'date_of_birth' => '2000-01-01',
          'phone_number' => '',
          'address' => {},
          'sponsor_is_deceased' => true,
          'date_of_death' => '2000-01-01',
          'date_of_marriage' => '',
          'is_active_service_death' => false
        },
        'applicants' => [
          {
            'applicant_relationship_origin' => { 'relationship_to_veteran' => 'blood' },
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
            'applicant_phone' => '(123) 123-1234',
            'applicant_gender' => { 'gender' => 'MALE' },
            'applicant_relationship_to_sponsor' => { 'relationship_to_veteran' => 'CHILD' },
            'applicant_dependent_status' => { 'status' => 'enrolled' },
            'applicant_enrolled_in_ohi' => false,
            'applicant_dob' => '2000-01-01',
            'applicant_name' => { 'first' => 'Johnny', 'middle' => 'T', 'last' => 'Alvin', 'suffix' => 'Jr.' },
            'applicant_medicare_status' => { 'eligibility' => 'enrolled' },
            'applicant_medicare_part_d' => { 'enrollment' => 'enrolled' },
            'applicant_has_ohi' => { 'has_ohi' => 'yes' },
            'ssn_or_tin' => '345345345',
            'vet_relationship' => 'CHILD',
            'childtype' => { 'relationship_to_veteran' => 'blood' },
            'applicant_supporting_documents' => []
          }
        ],
        'certification' => {
          'date' => '2000-01-01',
          'last_name' => 'Jones',
          'middle_initial' => '',
          'first_name' => 'Certifier',
          'phone_number' => '(123) 123-1234',
          'relationship' => 'spouse; child; thirdParty',
          'street_address' => '123 Certifier Street ',
          'city' => 'Citytown',
          'state' => 'AL',
          'postal_code' => '12312'
        },
        'statement_of_truth_signature' => 'certifier jones'
      }
    end

    let(:uuid) { 'some_unique_uuid' }

    before do
      # Stub UUID generation to return a fixed value for consistency in tests
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
    end

    it 'returns the correct structure' do
      expect(result).to have_key('applicationType')
      expect(result).to have_key('applicationUUID')
      expect(result).to have_key('sponsor')
      expect(result).to have_key('beneficiaries')
      expect(result).to have_key('certification')
    end

    it 'maps veteran data correctly' do
      sponsor = result['sponsor']
      expect(sponsor['firstName']).to eq('Joe')
      expect(sponsor['lastName']).to eq('Johnson')
      expect(sponsor['ssn']).to eq('123123123')
      expect(sponsor['dateOfBirth']).to eq('2000-01-01')
      expect(sponsor['isDeceased']).to be(true)
      expect(sponsor['dateOfDeath']).to eq('2000-01-01')
      expect(sponsor['address']).to eq({ 'streetAddress' => 'NA', 'city' => 'NA', 'state' => 'NA', 'zipCode' => 'NA' })
    end

    it 'maps applicant data correctly' do
      beneficiary = result['beneficiaries'].first
      expect(beneficiary['firstName']).to eq('Johnny')
      expect(beneficiary['lastName']).to eq('Alvin')
      expect(beneficiary['middleInitial']).to eq('T')
      expect(beneficiary['ssn']).to eq('345345345')
      expect(beneficiary['emailAddress']).to eq('johnny@alvin.gov')
      expect(beneficiary['phoneNumber']).to eq('(123) 123-1234')
      expect(beneficiary['gender']).to eq('MALE')
      expect(beneficiary['enrolledInMedicare']).to be(true)
      expect(beneficiary['hasOtherInsurance']).to be(true)
      expect(beneficiary['relationshipToSponsor']).to eq('CHILD')
      expect(beneficiary['childtype']).to eq('blood')
      expect(beneficiary['dateOfBirth']).to eq('2000-01-01')
    end

    it 'maps certification data correctly' do
      certification = result['certification']
      expect(certification['signature']).to eq('certifier jones')
      expect(certification['signatureDate']).to eq('2000-01-01')
      expect(certification['firstName']).to eq('Certifier')
      expect(certification['lastName']).to eq('Jones')
      expect(certification['middleInitial']).to eq('')
      expect(certification['phoneNumber']).to eq('(123) 123-1234')
    end

    context 'when there is missing data' do
      let(:parsed_form_data) do
        {
          'veteran' => {
            'full_name' => { 'first' => nil, 'last' => 'Johnson' },
            'ssn_or_tin' => nil,
            'va_claim_number' => nil,
            'date_of_birth' => nil
          },
          'applicants' => [],
          'statement_of_truth_signature' => nil,
          'certification' => {}
        }
      end

      it 'handles missing veteran data gracefully' do
        result = described_class.new.convert_to_champva_application(parsed_form_data)
        expect(result['sponsor']['firstName']).to be_nil
        expect(result['sponsor']['ssn']).to be_nil
        expect(result['sponsor']['dateOfBirth']).to be_nil
      end

      it 'handles missing applicant data gracefully' do
        result = described_class.new.convert_to_champva_application(parsed_form_data)
        expect(result['beneficiaries']).to be_empty
      end
    end
  end

  # Temporary, delete me
  # This test is used to hit the production endpoint when running locally.
  # It can be removed once we have some real code that uses the VES API client.
  describe 'hit the production endpoint', skip: 'this is useful as a way to hit the API during local development' do
    let(:forced_headers) do
      {
        :content_type => 'application/json',
        # use the following line when running locally tp pull the key from an environment variable
        'x-api-key' => ENV.fetch('VES_API_KEY'), # to set: export VES_API_KEY=insert1the2api3key4here
        'transactionUUId' => '1234',
        'acting-user' => ''
      }
    end

    before do
      allow_any_instance_of(IvcChampva::VesApi::Client).to receive(:headers).with(anything, anything)
                                                                            .and_return(forced_headers)
    end
  end
end
