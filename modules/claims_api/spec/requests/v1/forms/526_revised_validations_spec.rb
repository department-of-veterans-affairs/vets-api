# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/standard_data_service'
require_relative '../../../../app/controllers/concerns/claims_api/revised_disability_compensation_validations'

RSpec.describe ClaimsApi::RevisedDisabilityCompensationValidations do
  # Create a test class that includes the module
  # Create an instance to test with
  subject { test_class.new(form_attributes) }

  let(:test_class) do
    Class.new do
      include ClaimsApi::RevisedDisabilityCompensationValidations
      attr_accessor :form_attributes

      def initialize(attributes = {})
        @form_attributes = attributes
      end
    end
  end
  let(:form_attributes) { {} }

  describe '#validate_form_526_submission_claim_date!' do
    context 'when claim date is blank' do
      it 'does not raise an error' do
        expect { subject.validate_form_526_submission_claim_date! }.not_to raise_error
      end
    end

    context 'when claim date is in the past' do
      let(:form_attributes) { { 'claimDate' => 1.day.ago.iso8601 } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_submission_claim_date! }.not_to raise_error
      end
    end

    context 'when claim date is in the future' do
      let(:form_attributes) { { 'claimDate' => 1.day.from_now.iso8601 } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_submission_claim_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_location_codes!' do
    context 'when service periods are in the past' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyEndDate' => 1.year.ago.to_date.iso8601, 'separationLocationCode' => '123' }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_location_codes! }.not_to raise_error
      end
    end

    context 'when service periods are in the future' do
      let(:brd_client) { instance_double(ClaimsApi::BRD) }
      let(:separation_locations) { [{ id: '123' }, { id: '456' }] }
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyEndDate' => 1.year.from_now.to_date.iso8601, 'separationLocationCode' => '123' }
            ]
          }
        }
      end

      before do
        allow(ClaimsApi::BRD).to receive(:new).and_return(brd_client)
        allow(brd_client).to receive(:intake_sites).and_return(separation_locations)
      end

      context 'with a valid separation location code' do
        it 'does not raise an error' do
          expect { subject.validate_form_526_location_codes! }.not_to raise_error
        end
      end

      context 'with an invalid separation location code' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'servicePeriods' => [
                { 'activeDutyEndDate' => 1.year.from_now.to_date.iso8601, 'separationLocationCode' => '999' }
              ]
            }
          }
        end

        it 'raises an InvalidFieldValue error' do
          expect { subject.validate_form_526_location_codes! }
            .to raise_error(Common::Exceptions::InvalidFieldValue)
        end
      end

      context 'with multiple service periods' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'servicePeriods' => [
                { 'activeDutyEndDate' => 1.year.ago.to_date.iso8601, 'separationLocationCode' => '999' },
                { 'activeDutyEndDate' => 1.year.from_now.to_date.iso8601, 'separationLocationCode' => '123' }
              ]
            }
          }
        end

        it 'only validates future service periods' do
          expect { subject.validate_form_526_location_codes! }.not_to raise_error
        end
      end
    end

    context 'when BRD client raises an error' do
      let(:brd_client) { instance_double(ClaimsApi::BRD) }
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyEndDate' => 1.year.from_now.to_date.iso8601, 'separationLocationCode' => '123' }
            ]
          }
        }
      end

      before do
        allow(ClaimsApi::BRD).to receive(:new).and_return(brd_client)
        allow(brd_client).to receive(:intake_sites).and_raise(
          StandardError.new('Failed to retrieve intake sites')
        )
      end

      it 'propagates a ServiceUnavailable error' do
        expect { subject.validate_form_526_location_codes! }
          .to raise_error(Common::Exceptions::ServiceUnavailable)
      end
    end
  end

  describe '#validate_service_periods_quantity!' do
    context 'when <= 100 service periods are provided' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => Array.new(100) do |_i|
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => '2005-01-01'
              }
            end
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_service_periods_quantity! }.not_to raise_error
      end
    end

    context 'when > 100 service periods are provided' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => Array.new(101) do |_i|
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => '2005-01-01'
              }
            end
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_service_periods_quantity! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_service_periods_chronology!' do
    context 'when service period dates are in correct chronological order' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => '2005-01-01'
              }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_service_periods_chronology! }.not_to raise_error
      end
    end

    context 'when service period end date is missing' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => nil
              }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_service_periods_chronology! }.not_to raise_error
      end
    end

    context 'when service period end date is before begin date' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2005-01-01',
                'activeDutyEndDate' => '2000-01-01'
              }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_service_periods_chronology! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'with multiple service periods with mixed validity' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => '2005-01-01'
              },
              {
                'activeDutyBeginDate' => '2010-01-01',
                'activeDutyEndDate' => '2008-01-01'
              }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error for the invalid period' do
        expect { subject.validate_service_periods_chronology! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_no_active_duty_end_date_more_than_180_days_in_future!' do
    context 'when service period end date is less than 180 days in the future' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2020-01-01',
                'activeDutyEndDate' => 90.days.from_now.to_date.iso8601
              }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }.not_to raise_error
      end
    end

    context 'when service period end date is exactly 180 days in the future' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2020-01-01',
                'activeDutyEndDate' => 180.days.from_now.to_date.iso8601
              }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }.not_to raise_error
      end
    end

    context 'when service period end date is more than 180 days in the future' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2020-01-01',
                'activeDutyEndDate' => 181.days.from_now.to_date.iso8601
              }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when service period end date is missing' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2020-01-01',
                'activeDutyEndDate' => nil
              }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }.not_to raise_error
      end
    end

    context 'with multiple service periods with mixed validity' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2020-01-01',
                'activeDutyEndDate' => 90.days.from_now.to_date.iso8601
              },
              {
                'activeDutyBeginDate' => '2021-01-01',
                'activeDutyEndDate' => 200.days.from_now.to_date.iso8601
              }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error for the invalid period' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_title10_activation_date!' do
    let(:service_periods) do
      [
        { 'activeDutyBeginDate' => '2000-01-01', 'activeDutyEndDate' => '2005-01-01' },
        { 'activeDutyBeginDate' => '2010-01-01', 'activeDutyEndDate' => '2015-01-01' }
      ]
    end

    let(:form_attributes) do
      {
        'serviceInformation' => {
          'servicePeriods' => service_periods,
          'reservesNationalGuardService' => {
            'title10Activation' => { 'title10ActivationDate' => title10_activation_date }
          }
        }
      }
    end

    context 'when title10ActivationDate is after the earliest begin date and not in the future' do
      let(:title10_activation_date) { '2001-01-01' }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_activation_date! }.not_to raise_error
      end
    end

    context 'when title10ActivationDate is before the earliest begin date' do
      let(:title10_activation_date) { '1999-12-31' }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_title10_activation_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when title10ActivationDate is in the future' do
      let(:title10_activation_date) { 1.day.from_now.to_date.iso8601 }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_title10_activation_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end
end
