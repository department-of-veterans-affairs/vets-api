# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_validation'

# Calling private methods so needed to wrap it in a class
class TestDisabilityCompensationValidationClass
  include ClaimsApi::V2::DisabilityCompensationValidation
end

describe TestDisabilityCompensationValidationClass do
  subject(:test_526_validation_instance) { described_class.new }

  let(:auto_claim) do
    JSON.parse(
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
    )
  end

  let(:created_at) { Timecop.freeze(Time.zone.now) }
  let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }

  describe '#remove_chars' do
    let(:date_string) { form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] }

    it 'removes the -DD when the date string has a suffix of -DD' do
      result = test_526_validation_instance.send(:remove_chars, date_string)
      expect(result).to eq('2008-11')
    end
  end

  describe '#date_has_day?' do
    let(:date_string_with_day) { form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] }
    let(:date_string_without_day) { form_attributes['serviceInformation']['confinements'][1]['approximateBeginDate'] }

    it 'returns TRUE when the date is formatted YYYY-MM-DD' do
      result = test_526_validation_instance.send(:date_has_day?, date_string_with_day)
      expect(result).to eq(true)
    end

    it 'returns FALSE when the date is formatted YYYY-MM' do
      result = test_526_validation_instance.send(:date_has_day?, date_string_without_day)
      expect(result).to eq(false)
    end
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
end
