# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/disability_compensation_validations_helper'

describe ClaimsApi::DisabilityCompensationValidationsHelper do
  subject { test_class.new }

  let(:test_class) do
    Class.new { include ClaimsApi::DisabilityCompensationValidationsHelper }
  end

  describe '#eligible_for_future_end_date?' do
    let(:eligible_max_period) do
      {
        'serviceBranch' => 'Army Reserves',
        'activeDutyBeginDate' => 1.year.ago.to_date.iso8601,
        'activeDutyEndDate' => "#{Time.current.year + 1}-12-20"
      }
    end
    let(:ineligible_max_period) do
      {
        'serviceBranch' => 'Navy',
        'activeDutyBeginDate' => 1.year.ago.to_date.iso8601,
        'activeDutyEndDate' => "#{Time.current.year + 1}-12-20"
      }
    end
    let(:eligible_service_periods) do
      [
        {
          'serviceBranch' => 'Army',
          'activeDutyBeginDate' => 3.years.ago.to_date.iso8601,
          'activeDutyEndDate' => 1.year.ago.to_date.iso8601
        },
        {
          'serviceBranch' => 'Army',
          'activeDutyBeginDate' => 5.years.ago.to_date.iso8601,
          'activeDutyEndDate' => 7.years.ago.to_date.iso8601
        }
      ]
    end

    context 'eligible' do
      it 'if there is a past servicePeriod, the current serviceBranch is Reserves or Guard and end date > 180 days' do
        res = subject.send(:eligible_for_future_end_date?, eligible_max_period, eligible_service_periods)

        expect(res).to be(true)
      end
    end

    context 'ineligible' do
      it 'if the most recent serviceBranch is not Reserves or Guard and end date > 180 days' do
        res = subject.send(:eligible_for_future_end_date?, ineligible_max_period, eligible_service_periods)

        expect(res).to be(false)
      end
    end
  end
end
