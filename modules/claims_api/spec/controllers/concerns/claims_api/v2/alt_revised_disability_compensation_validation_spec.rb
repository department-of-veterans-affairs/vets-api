# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_validation'

# Calling private methods so needed to wrap it in a class
class AltTestDisabilityCompensationValidationClass
  include ClaimsApi::V2::AltRevisedDisabilityCompensationValidation

  attr_accessor :request, :params
  attr_reader :auth_headers

  def form_attributes
    @form_attributes ||= JSON.parse(
      Rails.root.join(
        'modules',
        'claims_api',
        'spec',
        'fixtures',
        'v2',
        'veterans',
        'disability_compensation',
        'form_526_json_api.json'
      ).read
    ).dig('data', 'attributes')
  end
end

describe AltTestDisabilityCompensationValidationClass, vcr: 'brd/countries' do
  subject(:test_526_validation_instance) { described_class.new }

  let(:created_at) { Timecop.freeze(Time.zone.now) }

  def current_error_array
    test_526_validation_instance.instance_variable_get('@errors')
  end

  describe '#alt_rev_validate_service_after_13th_birthday!' do
    context 'when the service periods are after the 13th birthday' do
      let(:auth_headers) do
        {
          'va_eauth_birthdate' => 35.years.ago.to_date.iso8601
        }
      end

      it 'does not raise an error' do
        allow_any_instance_of(described_class).to receive(:auth_headers).and_return(auth_headers)

        expect { subject.send(:alt_rev_validate_service_after_13th_birthday!) }.not_to raise_error
      end
    end

    context 'when there are service period dates before the 13th birthday' do
      let(:birthdate) { 12.years.ago.to_date.iso8601 }
      let(:auth_headers) do
        {
          'va_eauth_birthdate' => birthdate
        }
      end
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => 15.years.ago.to_date.iso8601,
                'activeDutyEndDate' => 5.years.ago.to_date.iso8601
              }
            ]
          }
        }
      end

      it 'raises an error' do
        allow_any_instance_of(described_class).to receive(:auth_headers).and_return(auth_headers)

        subject.send(:alt_rev_validate_service_after_13th_birthday!)

        expect(current_error_array.count).to eq(1)
        expect(current_error_array[0][:detail]).to eq(
          "Active Duty Begin Date (0) cannot be before Veteran's thirteenth birthday."
        )
        expect(current_error_array[0][:source]).to eq(
          'serviceInformation/servicePeriods/0/activeDutyBeginDate'
        )
      end
    end
  end

  describe '#remove_chars' do
    let(:date_string) { subject.form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] }

    it 'removes the -DD when the date string has a suffix of -DD' do
      result = test_526_validation_instance.send(:remove_chars, date_string)
      expect(result).to eq('2008-11')
    end
  end

  describe '#date_has_day?' do
    let(:date_string_with_day) do
      subject.form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate']
    end
    let(:date_string_without_day) do
      subject.form_attributes['serviceInformation']['confinements'][1]['approximateBeginDate']
    end

    it 'returns TRUE when the date is formatted YYYY-MM-DD' do
      result = test_526_validation_instance.send(:date_has_day?, date_string_with_day)
      expect(result).to be(true)
    end

    it 'returns FALSE when the date is formatted YYYY-MM' do
      result = test_526_validation_instance.send(:date_has_day?, date_string_without_day)
      expect(result).to be(false)
    end
  end

  describe '#validate_form_526_location_codes' do
    let(:no_separation_code) do
      { 'servicePeriods' => [
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => '2023-10-30'
        }
      ] }
    end

    let(:valid_and_invalid_separation_codes) do
      { 'servicePeriods' => [
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => '2023-10-30',
          'separationLocationCode' => '24912' # valid
        },
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => '2023-10-30',
          'separationLocationCode' => '123456' # invalid
        }
      ] }
    end

    let(:valid_and_no_separation_codes) do
      { 'servicePeriods' => [
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => '2023-10-30',
          'separationLocationCode' => '24912' # valid
        },
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => '2023-10-30'
        } # no separation location code
      ] }
    end

    let(:service_periods) { subject.form_attributes['serviceInformation'] }

    # rubocop:disable RSpec/SubjectStub
    context 'when a separation location code is present' do
      before do
        separation_locations = [
          { id: 24_912, description: 'AF Academy' },
          { id: 26_722, description: 'ANG Hub' }
        ]
        allow(test_526_validation_instance).to receive(:retrieve_separation_locations)
          .and_return(separation_locations)
      end

      context 'when the location code is valid' do
        it 'returns no errors' do
          service_periods['servicePeriods'][0]['separationLocationCode'] = '24912'
          test_526_validation_instance.send(:alt_rev_validate_form_526_location_codes, service_periods)
          errors = test_526_validation_instance.send(:error_collection)

          expect(errors).to be_empty
        end
      end

      context 'when the location code is invalid' do
        it 'adds an error to the errors array' do
          service_periods['servicePeriods'][0]['separationLocationCode'] = '123456'
          test_526_validation_instance.send(:alt_rev_validate_form_526_location_codes, service_periods)
          errors = test_526_validation_instance.send(:error_collection)

          expect(errors.size).to eq(1)
        end
      end

      context 'when the location code is valid in some service periods and invalid in others' do
        it 'adds an error to the errors array' do
          test_526_validation_instance.send(:alt_rev_validate_form_526_location_codes,
                                            valid_and_invalid_separation_codes)
          errors = test_526_validation_instance.send(:error_collection)

          expect(errors.size).to eq(1)
        end
      end

      context 'when the location code is valid in some service periods and not present in others' do
        it 'returns no errors' do
          test_526_validation_instance.send(:alt_rev_validate_form_526_location_codes, valid_and_no_separation_codes)
          errors = test_526_validation_instance.send(:error_collection)

          expect(errors).to be_empty
        end
      end
    end

    context 'when a separation location code is not present' do
      it 'does not retrieve the location codes and skips validation' do
        test_526_validation_instance.send(:alt_rev_validate_form_526_location_codes, no_separation_code)
        errors = test_526_validation_instance.send(:error_collection)

        expect(test_526_validation_instance).not_to receive(:retrieve_separation_locations)
        expect(errors).to be_empty
      end
    end
    # rubocop:enable RSpec/SubjectStub
  end

  describe 'military address validations' do
    let(:valid_military_address) do
      {
        'addressLine1' => 'CMR 468 Box 1181',
        'city' => 'DPO',
        'country' => 'USA',
        'zipFirstFive' => '09277',
        'state' => 'AE'
      }
    end
    let(:invalid_military_address) do
      {
        'addressLine1' => 'CMR 468 Box 1181',
        'city' => 'FPO',
        'country' => 'USA',
        'zipFirstFive' => '09277',
        'state' => 'AL'
      }
    end

    describe '#address_is_military?' do
      it 'correctly identifies address as MILITARY' do
        check = test_526_validation_instance.send(:address_is_military?, valid_military_address)
        expect(check).to be(true)
      end

      it 'correctly identifies address as not MILITARY if no military codes are used' do
        check = test_526_validation_instance.send(:address_is_military?,
                                                  subject.form_attributes['veteranIdentification']['mailingAddress'])
        expect(check).to be(false)
      end
    end

    describe '#validate_form_526_address_type' do
      context 'mailingAddress' do
        it 'returns an error with an incorrect MILITARY address combination' do
          subject.form_attributes['veteranIdentification']['mailingAddress'] = invalid_military_address
          test_526_validation_instance.send(:alt_rev_validate_form_526_address_type)
          expect(current_error_array[0][:detail]).to eq('Invalid city and military postal combination.')
          expect(current_error_array[0][:source]).to eq('/veteranIdentification/mailingAddress/')
        end

        it 'handles a correct MILITARY address combination' do
          subject.form_attributes['veteranIdentification']['mailingAddress'] = valid_military_address
          test_526_validation_instance.send(:alt_rev_validate_form_526_address_type)
          test_526_validation_instance.instance_variable_get('@errors')
          expect(current_error_array).to be_nil
        end

        it 'handles a DOMESTIC address' do
          test_526_validation_instance.send(:alt_rev_validate_form_526_address_type)
          test_526_validation_instance.instance_variable_get('@errors')
          expect(current_error_array).to be_nil
        end
      end
    end
  end

  describe '#date_is_valid' do
    let(:begin_date) { '2017-02-29' }
    let(:begin_prop) { '/toxicExposure/additionalHazardExposures/exposureDates/beginDate' }
    let(:end_date) { '2017-02-28' }
    let(:end_prop) { '/toxicExposure/additionalHazardExposures/exposureDates/endDate' }

    it 'returns false when a date is invalid' do
      result = test_526_validation_instance.send(:date_is_valid?, begin_date, begin_prop)
      expect(result).to be(false)
    end

    it 'returns true when a date is valid' do
      result = test_526_validation_instance.send(:date_is_valid?, end_date, end_prop)
      expect(result).to be(true)
    end
  end

  describe '#alt_rev_validate_alternate_names' do
    let(:service_information) { test_526_validation_instance.form_attributes['serviceInformation'] }

    context 'when alternate names is an empty array' do
      it 'stubs the value to nil' do
        service_information['alternateNames'] = []
        test_526_validation_instance.send(:alt_rev_validate_alternate_names, service_information)

        expect(current_error_array).to be_nil
        expect(test_526_validation_instance.form_attributes['serviceInformation']['alternateNames']).to be_nil
      end
    end

    context 'when alternate names contains invalid characters' do
      it 'returns an error for names with invalid characters' do
        service_information['alternateNames'] = ['valid-name', 'invalid@name']
        test_526_validation_instance.send(:alt_rev_validate_alternate_names, service_information)

        expect(current_error_array.size).to eq(1)
        expect(current_error_array[0][:source]).to eq('/serviceInformation/alternateNames/1')
        expect(current_error_array[0][:detail]).to include('contains invalid characters')
        expect(current_error_array[0][:detail]).to include('^([-a-zA-Z0-9/\']+( ?))+$')
      end
    end

    context 'when alternate names contains double spaces' do
      it 'returns an error for names with double spaces' do
        service_information['alternateNames'] = ['name  with  double  spaces']
        test_526_validation_instance.send(:alt_rev_validate_alternate_names, service_information)

        expect(current_error_array.size).to eq(1)
        expect(current_error_array[0][:source]).to eq('/serviceInformation/alternateNames/0')
        expect(current_error_array[0][:detail]).to include('contains invalid characters')
      end
    end

    context 'when alternate names are valid' do
      it 'returns no errors' do
        service_information['alternateNames'] = ["john o'malley", 'jane-doe', 'bob123']
        test_526_validation_instance.send(:alt_rev_validate_alternate_names, service_information)

        expect(current_error_array).to be_nil
      end
    end

    context 'when alternate names contains duplicates' do
      it 'returns an error for duplicate names' do
        service_information['alternateNames'] = ['John Doe', 'jane smith', 'john doe']
        test_526_validation_instance.send(:alt_rev_validate_alternate_names, service_information)

        expect(current_error_array.size).to eq(1)
        expect(current_error_array[0][:source]).to eq('/serviceInformation/alternateNames')
        expect(current_error_array[0][:detail]).to eq('Names entered as an alternate name must be unique.')
      end
    end
  end

  describe 'validation of claimant mailing address elements' do
    context 'when the country is valid' do # country is USA in the JSON
      it 'responds with true' do
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_current_mailing_address_country)
        expect(res).to be_nil
      end
    end

    context 'when the country is invalid' do
      it 'returns an error array' do
        subject.form_attributes['veteranIdentification']['mailingAddress']['country'] = 'United States of Nada'
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_current_mailing_address_country)
        expect(res[0][:detail]).to eq('The country provided is not valid.')
        expect(res[0][:source]).to eq('/veteranIdentification/mailingAddress/country')
      end
    end

    context 'when the state is not provided and country is not USA' do
      it 'responds with true' do
        subject.form_attributes['veteranIdentification']['mailingAddress']['country'] = 'Afghanistan'
        subject.form_attributes['veteranIdentification']['mailingAddress']['internationalPostalCode'] = '151-8557'
        subject.form_attributes['veteranIdentification']['mailingAddress']['zipFirstFive'] = ''
        subject.form_attributes['veteranIdentification']['mailingAddress']['state'] = nil
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_current_mailing_address_state)
        expect(res).to be_nil
      end
    end
  end

  describe 'validation of claimant change of address elements' do
    context "'typeOfAddressChange','addressLine1','country' are conditionally required" do
      context 'without the required country value present' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['country'] = ''
          res = test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_country)
          expect(res[0][:detail]).to eq('The country provided is not valid.')
          expect(res[0][:source]).to eq('/changeOfAddress/country')
        end
      end

      context 'when beginDate is an invalid date value' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '2018-09-45'
          res = test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_beginning_date)
          expect(res[0][:detail]).to eq('beginDate is not a valid date.')
          expect(res[0][:source]).to eq('/changeOfAddress/dates/beginDate')
        end
      end
    end

    context 'without the required typeOfAddressChange' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['typeOfAddressChange'] = ''
        change_of_address = subject.form_attributes['changeOfAddress']
        res = test_526_validation_instance.send(
          :alt_rev_validate_form_526_coa_type_of_address_change_presence,
          change_of_address,
          '/changeOfAddress'
        )
        expect(res[0][:detail]).to eq('The typeOfAddressChange is required for /changeOfAddress.')
        expect(res[0][:source]).to eq('/changeOfAddress')
      end
    end

    context 'without the required addressLine1' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['addressLine1'] = ''
        change_of_address = subject.form_attributes['changeOfAddress']
        res = test_526_validation_instance.send(
          :alt_rev_validate_form_526_coa_address_line_one_presence,
          change_of_address,
          '/changeOfAddress'
        )
        expect(res[0][:detail]).to eq('The addressLine1 is required for /changeOfAddress.')
        expect(res[0][:source]).to eq('/changeOfAddress')
      end
    end

    context 'when the country is valid' do # country is USA in the JSON
      it 'responds with true' do
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_country)
        expect(res).to be_nil
      end
    end

    context 'when the country is invalid' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['country'] = 'United States of Nada'
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_country)
        expect(res[0][:detail]).to eq('The country provided is not valid.')
        expect(res[0][:source]).to eq('/changeOfAddress/country')
      end
    end

    context 'conditional validations when the country is USA' do
      context 'zipfirstFive is not included' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['zipFirstFive'] = ''
          test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_zip)
          expect(current_error_array[0][:detail]).to eq('The zipFirstFive is required if the country is USA.')
          expect(current_error_array[0][:source]).to eq('/changeOfAddress/')
        end
      end

      context 'state is not included' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['state'] = ''
          test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_zip)
          expect(current_error_array[0][:detail]).to eq('The state is required if the country is USA.')
          expect(current_error_array[0][:source]).to eq('/changeOfAddress/')
        end
      end

      context 'internationalPostalCode is included' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['internationalPostalCode'] = '333-444'
          test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_zip)
          expect(current_error_array[0][:detail])
            .to eq('The internationalPostalCode should not be provided if the country is USA.')
          expect(current_error_array[0][:source]).to eq('/changeOfAddress/internationalPostalCode')
        end
      end
    end

    context 'when the country is not provided' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['country'] = ''
        change_of_address = subject.form_attributes['changeOfAddress']
        res = test_526_validation_instance.send(
          :alt_rev_validate_form_526_coa_country_presence,
          change_of_address,
          '/changeOfAddress'
        )
        expect(res[0][:detail]).to eq('The country is required for /changeOfAddress.')
        expect(res[0][:source]).to eq('/changeOfAddress')
      end
    end

    context 'without the required city' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['city'] = ''
        change_of_address = subject.form_attributes['changeOfAddress']
        res = test_526_validation_instance.send(
          :alt_rev_validate_form_526_coa_city_presence,
          change_of_address,
          '/changeOfAddress'
        )
        expect(res[0][:detail]).to eq('The city is required for /changeOfAddress.')
        expect(res[0][:source]).to eq('/changeOfAddress')
      end
    end

    context 'when the end date is an invalid date' do
      end_date = '2022-91-99'
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '2023-01-01'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = end_date
        test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_ending_date)
        expect(current_error_array[0][:detail]).to eq("#{end_date} is not a valid date.")
        expect(current_error_array[0][:source]).to eq('data/attributes/changeOfAddress/dates/endDate')
      end
    end

    context 'when the begin date is after the end date' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '2023-01-01'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = '2022-01-01'
        res = test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_ending_date)
        expect(res[0][:detail]).to eq('endDate needs to be after beginDate.')
        expect(res[0][:source]).to eq('/changeOfAddress/dates/endDate')
      end
    end

    context 'when the type is temporary and begin date is in the past' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['typeOfAddressChange'] = 'TEMPORARY'
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '2023-01-01'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = '2024-01-01'
        test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_beginning_date)
        expect(current_error_array[0][:detail]).to eq('Change of address beginDate must be ' \
                                                      'in the future if addressChangeType is TEMPORARY')
        expect(current_error_array[0][:source]).to eq('/changeOfAddress/dates/beginDate')
      end
    end

    context 'when the type is permanent the end date is prohibited' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['typeOfAddressChange'] = 'PERMANENT'
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '01-01-2023'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = '01-01-2024'
        test_526_validation_instance.send(:alt_rev_validate_form_526_change_of_address_ending_date)
        expect(current_error_array[0][:detail]).to eq('Change of address endDate cannot be included ' \
                                                      'when typeOfAddressChange is PERMANENT')
        expect(current_error_array[0][:source]).to eq('/changeOfAddress/dates/endDate')
      end
    end
  end

  describe 'validation for BDD_PROGRAM claim' do
    future_date = "#{Time.current.year + 1}-12-20"

    let(:valid_service_info_for_bdd) do
      {
        'servicePeriods' => [
          {
            'serviceBranch' => 'Air Force Reserves',
            'serviceComponent' => 'Reserves',
            'activeDutyBeginDate' => '2015-11-14',
            'activeDutyEndDate' => future_date
          }
        ],
        'reservesNationalGuardService' => {
          'component' => 'National Guard',
          'obligationTermsOfService' => {
            'beginDate' => '1990-11-24',
            'endDate' => '1995-11-17'
          },
          'unitName' => 'National Guard Unit Name',
          'unitAddress' => '1243 Main Street',
          'unitPhone' => {
            'areaCode' => '555',
            'phoneNumber' => '5555555'
          },
          'receivingInactiveDutyTrainingPay' => 'YES'
        },
        'federalActivation' => {
          'activationDate' => '2023-10-01',
          'anticipatedSeparationDate' => future_date
        }
      }
    end

    def validate_field(field_path, expected_detail, expected_source)
      keys = field_path.split('.')
      current_hash = valid_service_info_for_bdd

      keys[0..-2].each do |key|
        current_hash = current_hash[key]
      end

      current_hash[keys.last] = '' # set the specified field to empty string to omit

      invalid_service_info_for_bdd = valid_service_info_for_bdd
      subject.form_attributes['serviceInformation'] = invalid_service_info_for_bdd
      test_526_validation_instance.send(:alt_rev_validate_federal_activation_values, invalid_service_info_for_bdd)

      expect(current_error_array[0][:detail]).to eq(expected_detail)
      expect(current_error_array[0][:source]).to eq(expected_source)
    end

    context 'when federalActivation is present' do
      it 'and all the required attributes are present' do
        test_526_validation_instance.send(:alt_rev_validate_federal_activation_values, valid_service_info_for_bdd)
        expect(current_error_array).to be_nil
      end

      # rubocop:disable RSpec/NoExpectationExample
      it 'requires federalActivation.activationDate' do
        validate_field(
          'federalActivation.activationDate',
          'activationDate is missing or blank',
          'serviceInformation/federalActivation/'
        )
      end

      it 'requires federalActivation.anticipatedSeparationDate' do
        validate_field(
          'federalActivation.anticipatedSeparationDate',
          'anticipatedSeparationDate is missing or blank',
          'serviceInformation/federalActivation/'
        )
      end

      it 'requires reservesNationalGuardService.obligationTermsOfService.beginDate' do
        validate_field(
          'reservesNationalGuardService.obligationTermsOfService.beginDate',
          'beginDate is missing or blank',
          'serviceInformation/reservesNationalGuardService/obligationTermsOfService/'
        )
      end

      it 'requires reservesNationalGuardService.obligationTermsOfService.endDate' do
        validate_field(
          'reservesNationalGuardService.obligationTermsOfService.endDate',
          'endDate is missing or blank',
          'serviceInformation/reservesNationalGuardService/obligationTermsOfService/'
        )
      end

      # rubocop:enable RSpec/NoExpectationExample
    end
  end
end
