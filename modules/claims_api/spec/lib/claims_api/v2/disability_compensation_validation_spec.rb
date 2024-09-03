# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_validation'

# Calling private methods so needed to wrap it in a class
class TestDisabilityCompensationValidationClass
  include ClaimsApi::V2::DisabilityCompensationValidation

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

describe TestDisabilityCompensationValidationClass, vcr: 'brd/countries' do
  subject(:test_526_validation_instance) { described_class.new }

  let(:created_at) { Timecop.freeze(Time.zone.now) }

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
      expect(result).to eq(true)
    end

    it 'returns FALSE when the date is formatted YYYY-MM' do
      result = test_526_validation_instance.send(:date_has_day?, date_string_without_day)
      expect(result).to eq(false)
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

    let(:service_period_end_in_future) do
      { 'servicePeriods' => [
        {
          'serviceBranch' => 'Public Health Service',
          'serviceComponent' => 'Active',
          'activeDutyBeginDate' => '2008-11-14',
          'activeDutyEndDate' => 2.days.from_now.strftime('%Y-%m-%d').to_s
        }
      ] }
    end

    let(:service_periods) { subject.form_attributes['serviceInformation'] }

    # rubocop:disable RSpec/SubjectStub
    context 'calls to retrieve codes' do
      before do
        allow(test_526_validation_instance).to receive(:retrieve_separation_locations).and_return([])
      end

      it 'retrives codes if separationLocationcode is present' do
        test_526_validation_instance.send(:validate_form_526_location_codes, service_periods)
        expect(test_526_validation_instance).to have_received(:retrieve_separation_locations)
      end
    end

    context 'does not call to retrieve codes' do
      it 'does not retrieve the codes if separationLocation is not present' do
        test_526_validation_instance.send(:validate_form_526_location_codes, no_separation_code)
        expect(test_526_validation_instance).not_to receive(:retrieve_separation_locations)
      end

      it 'does not retrieve the codes if activeDutyEndDate is in the future' do
        test_526_validation_instance.send(:validate_form_526_location_codes, service_period_end_in_future)
        expect(test_526_validation_instance).not_to receive(:retrieve_separation_locations)
      end
    end
    # rubocop:enable RSpec/SubjectStub
  end

  describe '#date_range_overlap?' do
    let(:date_begin_one) { '2018-06-04' }
    let(:date_end_one) { '2020-07-01' }
    let(:date_begin_two) { '2020-06-05' }
    let(:date_end_two) { '2020-07-01' }

    it 'returns true when the date ranges overlap' do
      begin_one = test_526_validation_instance.send(:date_regex_groups, date_begin_one)
      end_one = test_526_validation_instance.send(:date_regex_groups, date_end_one)
      begin_two = test_526_validation_instance.send(:date_regex_groups, date_begin_two)
      end_two = test_526_validation_instance.send(:date_regex_groups, date_end_two)
      result = test_526_validation_instance.send(:date_range_overlap?, begin_one..end_one, begin_two..end_two)
      expect(result).to eq(true)
    end

    it 'returns false when the date ranges do not overlap' do
      begin_one = test_526_validation_instance.send(:date_regex_groups, date_begin_one)
      end_one = test_526_validation_instance.send(:date_regex_groups, '2020-04-28')
      begin_two = test_526_validation_instance.send(:date_regex_groups, date_begin_two)
      end_two = test_526_validation_instance.send(:date_regex_groups, date_end_two)
      result = test_526_validation_instance.send(:date_range_overlap?, begin_one..end_one, begin_two..end_two)
      expect(result).to eq(false)
    end
  end

  describe '#date_is_valid' do
    let(:begin_date) { '2017-02-29' }
    let(:begin_prop) { '/toxicExposure/additionalHazardExposures/exposureDates/beginDate' }
    let(:end_date) { '2017-02-28' }
    let(:end_prop) { '/toxicExposure/additionalHazardExposures/exposureDates/endDate' }

    it 'returns false when a date is invalid' do
      result = test_526_validation_instance.send(:date_is_valid?, begin_date, begin_prop)
      expect(result).to eq(false)
    end

    it 'returns true when a date is valid' do
      result = test_526_validation_instance.send(:date_is_valid?, end_date, end_prop)
      expect(result).to eq(true)
    end
  end

  describe 'validation of claimant certification' do
    context 'when the cert is false' do
      it 'returns an error array' do
        subject.form_attributes['claimantCertification'] = false
        res = test_526_validation_instance.send(:validate_form_526_claimant_certification)
        expect(res[0][:detail]).to eq('claimantCertification must not be false.')
        expect(res[0][:source]).to eq('/claimantCertification')
      end
    end
  end

  describe 'validation of claimant mailing address elements' do
    context 'when the country is valid' do # country is USA in the JSON
      it 'responds with true' do
        res = test_526_validation_instance.send(:validate_form_526_current_mailing_address_country)
        expect(res).to be_nil
      end
    end

    context 'when the country is invalid' do
      it 'returns an error array' do
        subject.form_attributes['veteranIdentification']['mailingAddress']['country'] = 'United States of Nada'
        res = test_526_validation_instance.send(:validate_form_526_current_mailing_address_country)
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
        res = test_526_validation_instance.send(:validate_form_526_current_mailing_address_state)
        expect(res).to be_nil
      end
    end
  end

  describe 'validation of claimant change of address elements' do
    context "when any values present, 'dates','typeOfAddressChange','numberAndStreet','country' are required" do
      context 'without the required country value present' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['country'] = ''
          res = test_526_validation_instance.send(:validate_form_526_change_of_address_country)
          expect(res[0][:detail]).to eq('The country provided is not valid.')
          expect(res[0][:source]).to eq('/changeOfAddress/country')
        end
      end

      context 'without the required dates values present' do
        it 'returns an error array' do
          subject.form_attributes['changeOfAddress']['dates']['beginDate'] = ''
          res = test_526_validation_instance.send(:validate_form_526_change_of_address_beginning_date)
          expect(res[0][:detail]).to eq('beginDate is not a valid date.')
          expect(res[0][:source]).to eq('/changeOfAddress/dates/beginDate')
        end
      end
    end

    context 'when the country is valid' do # country is USA in the JSON
      it 'responds with true' do
        res = test_526_validation_instance.send(:validate_form_526_change_of_address_country)
        expect(res).to be_nil
      end
    end

    context 'when the country is invalid' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['country'] = 'United States of Nada'
        res = test_526_validation_instance.send(:validate_form_526_change_of_address_country)
        expect(res[0][:detail]).to eq('The country provided is not valid.')
        expect(res[0][:source]).to eq('/changeOfAddress/country')
      end
    end

    context 'when the begin date is after the end date' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '2023-01-01'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = '2022-01-01'
        res = test_526_validation_instance.send(:validate_form_526_change_of_address_ending_date)
        expect(res[0][:detail]).to eq('endDate is not a valid date.')
        expect(res[0][:source]).to eq('/changeOfAddress/dates/endDate')
      end
    end

    context 'when the type is permanent the end date is prohibited' do
      it 'returns an error array' do
        subject.form_attributes['changeOfAddress']['typeOfAddressChange'] = 'PERMANENT'
        subject.form_attributes['changeOfAddress']['dates']['beginDate'] = '01-01-2023'
        subject.form_attributes['changeOfAddress']['dates']['endDate'] = '01-01-2024'
        test_526_validation_instance.send(:validate_form_526_change_of_address_ending_date)
        errors = test_526_validation_instance.instance_variable_get('@errors')
        expect(errors[0][:detail]).to eq('Change of address endDate cannot be included ' \
                                         'when typeOfAddressChange is PERMANENT')
        expect(errors[0][:source]).to eq('/changeOfAddress/dates/endDate')
      end
    end
  end
end
