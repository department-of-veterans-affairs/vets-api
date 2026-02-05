# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/standard_data_service'
require_relative '../../../../app/controllers/concerns/claims_api/revised_disability_compensation_validations'

RSpec.describe ClaimsApi::RevisedDisabilityCompensationValidations do
  # Create a test class that includes the module
  # Create an instance to test with
  subject { test_class.new(auth_headers, form_attributes) }

  let(:test_class) do
    Class.new do
      include ClaimsApi::RevisedDisabilityCompensationValidations
      attr_accessor :form_attributes

      def initialize(auth_headers, attributes = {})
        @form_attributes = attributes
        @auth_headers = auth_headers
      end

      attr_reader :auth_headers

      def bgs_service
        # This will be stubbed in individual tests
      end
    end
  end
  let(:form_attributes) { {} }
  let(:auth_headers) do
    {
      'va_eauth_birthdate' => 20.years.ago.to_date.iso8601
    }
  end

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

    describe '#validate_service_after_13th_birthday!' do
      context 'when the service periods are after the 13th birthday' do
        it 'does not raise an error' do
          expect { subject.validate_service_after_13th_birthday! }.not_to raise_error
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
          age_thirteen = (birthdate.to_date + 13.years).to_s

          expect { subject.validate_service_after_13th_birthday! }
            .to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
              expect(error.errors[0][:detail]).to include(
                "before the Veteran's 13th birthdate: #{age_thirteen}, the claim can not be processed."
              )
            end
        end
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
          Common::Exceptions::ServiceUnavailable
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

    context 'when applicant is a reservist or National Guardsman with a prior ended service period' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2010-01-01',
                'activeDutyEndDate' => 200.days.from_now.to_date.iso8601
              },
              {
                'activeDutyBeginDate' => '2000-01-01',
                'activeDutyEndDate' => 1.year.ago.to_date.iso8601
              }
            ],
            'reservesNationalGuardService' => { 'someField' => 'someValue' }
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }.not_to raise_error
      end
    end

    context 'when applicant is a reservist or National Guardsman without a prior ended service period' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2010-01-01',
                'activeDutyEndDate' => 200.days.from_now.to_date.iso8601
              }
            ],
            'reservesNationalGuardService' => { 'someField' => 'someValue' }
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when applicant is not a reservist or National Guardsman and has a future end date' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              {
                'activeDutyBeginDate' => '2010-01-01',
                'activeDutyEndDate' => 200.days.from_now.to_date.iso8601
              }
            ]
            # reservesNationalGuardService is missing
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_no_active_duty_end_date_more_than_180_days_in_future! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_service_periods_begin_in_past!' do
    context 'when all begin dates are in the past' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyBeginDate' => 3.days.ago.to_date.to_s },
              { 'activeDutyBeginDate' => 5.days.ago.to_date.to_s }
            ]
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_service_periods_begin_in_past! }.not_to raise_error
      end
    end

    context 'when a begin date is today' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyBeginDate' => Time.zone.now.to_date.to_s }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect do
          subject.validate_form_526_service_periods_begin_in_past!
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when a begin date is in the future' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyBeginDate' => 2.days.from_now.to_date.to_s }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect do
          subject.validate_form_526_service_periods_begin_in_past!
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when multiple service periods and one is invalid' do
      let(:form_attributes) do
        {
          'serviceInformation' => {
            'servicePeriods' => [
              { 'activeDutyBeginDate' => 2.days.ago.to_date.to_s },
              { 'activeDutyBeginDate' => 2.days.from_now.to_date.to_s }
            ]
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect do
          subject.validate_form_526_service_periods_begin_in_past!
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
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

  describe '#validate_form_526_title10_anticipated_separation_date!' do
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
            'title10Activation' => {
              'title10ActivationDate' => title10_activation_date,
              'anticipatedSeparationDate' => anticipated_separation_date
            }
          }
        }
      }
    end

    # field validation tests
    # need to validate if this is expected behavior
    context 'when anticipatedSeparationDate is missing' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { nil }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    # need to validate if this is expected behavior
    context 'when title10ActivationDate is missing' do
      let(:title10_activation_date) { nil }
      let(:anticipated_separation_date) { 90.days.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    context 'when anticipatedSeparationDate is within 180 days of title10ActivationDate' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 90.days.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    context 'when anticipatedSeparationDate is more than 180 days from title10ActivationDate' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 200.days.from_now.to_date.iso8601 }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    # edge case tests
    context 'when anticipatedSeparationDate is exactly 180 days from title10ActivationDate' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 180.days.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    context 'when anticipatedSeparationDate is exactly today' do
      let(:title10_activation_date) { 1.day.ago.to_date.iso8601 }
      let(:anticipated_separation_date) { Time.zone.today.iso8601 }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when anticipatedSeparationDate is 179 days from title10ActivationDate' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 179.days.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    context 'when anticipatedSeparationDate is 181 days from title10ActivationDate' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 181.days.from_now.to_date.iso8601 }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when anticipatedSeparationDate is tomorrow' do
      let(:title10_activation_date) { Time.zone.today.iso8601 }
      let(:anticipated_separation_date) { 1.day.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end

    context 'when anticipatedSeparationDate equals title10ActivationDate' do
      let(:title10_activation_date) { 1.day.from_now.to_date.iso8601 }
      let(:anticipated_separation_date) { 1.day.from_now.to_date.iso8601 }

      it 'does not raise an error' do
        expect { subject.validate_form_526_title10_anticipated_separation_date! }.not_to raise_error
      end
    end
  end

  describe '#validate_form_526_current_mailing_address_country!' do
    # These country values are the example ones displayed in the API documentation
    # at https://developer.va.gov/explore/api/benefits-reference-data/docs?version=current
    let(:valid_countries) { %w[Bolivia China Serbia/Montenegro] }

    before do
      # Stubbing this because it's a method on the subject that fetches data from BRD
      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive(:valid_countries).and_return(valid_countries)
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when country is valid' do
      let(:form_attributes) do
        {
          'veteran' => {
            'currentMailingAddress' => {
              'country' => 'Bolivia'
            }
          }
        }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_current_mailing_address_country! }.not_to raise_error
      end
    end

    context 'when country is invalid' do
      let(:form_attributes) do
        {
          'veteran' => {
            'currentMailingAddress' => {
              'country' => '123'
            }
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_current_mailing_address_country! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when country is missing' do
      let(:form_attributes) do
        {
          'veteran' => {
            'currentMailingAddress' => {}
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_current_mailing_address_country! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_change_of_address!' do
    let(:valid_countries) { %w[USA Canada] }

    before do
      # Stubbing this because it's a method on the subject that fetches data from BRD
      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive(:valid_countries).and_return(valid_countries)
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when changeOfAddress is blank' do
      let(:form_attributes) { { 'veteran' => { 'changeOfAddress' => nil } } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_change_of_address! }.not_to raise_error
      end
    end

    context 'when addressChangeType is TEMPORARY' do
      let(:form_attributes) do
        {
          'veteran' => {
            'changeOfAddress' => {
              'addressChangeType' => 'TEMPORARY',
              'beginningDate' => 1.day.from_now.to_date.iso8601,
              'endingDate' => 2.days.from_now.to_date.iso8601,
              'country' => 'USA'
            }
          }
        }
      end

      it 'does not raise an error for valid dates and country' do
        expect { subject.validate_form_526_change_of_address! }.not_to raise_error
      end

      it 'raises error if beginningDate is not in the future' do
        form_attributes['veteran']['changeOfAddress']['beginningDate'] = 1.day.ago.to_date.iso8601
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end

      it 'raises error if endingDate is missing' do
        form_attributes['veteran']['changeOfAddress'].delete('endingDate')
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end

      it 'raises error if beginningDate is after or equal to endingDate' do
        form_attributes['veteran']['changeOfAddress']['endingDate'] = form_attributes.dig(
          'veteran', 'changeOfAddress', 'beginningDate'
        )
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end

      it 'raises error if country is invalid' do
        form_attributes['veteran']['changeOfAddress']['country'] = 'Invalid'
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when addressChangeType is PERMANENT' do
      let(:form_attributes) do
        {
          'veteran' => {
            'changeOfAddress' => {
              'addressChangeType' => 'PERMANENT',
              'endingDate' => nil,
              'country' => 'USA'
            }
          }
        }
      end

      it 'does not raise an error if endingDate is not present' do
        expect { subject.validate_form_526_change_of_address! }.not_to raise_error
      end

      it 'raises error if endingDate is present' do
        form_attributes['veteran']['changeOfAddress']['endingDate'] = 1.day.from_now.to_date.iso8601
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end

      it 'raises error if country is invalid' do
        form_attributes['veteran']['changeOfAddress']['country'] = 'Invalid'
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when country is missing' do
      let(:form_attributes) do
        {
          'veteran' => {
            'changeOfAddress' => {
              'addressChangeType' => 'PERMANENT'
              # country missing
            }
          }
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_change_of_address! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  # rubocop:disable RSpec/SubjectStub
  describe '#contention_classification_type_code_list' do
    let(:mock_list) { [{ clsfcn_id: '1234', end_dt: nil }, { clsfcn_id: '5678', end_dt: '2020-01-01' }] }
    let(:mock_data) { double('data', get_contention_classification_type_code_list: mock_list) }
    let(:mock_bgs_service) { double('bgs_service', data: mock_data) }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_526_validations_v1_local_bgs).and_return(false)
      allow(subject).to receive(:bgs_service).and_return(mock_bgs_service)
    end

    it 'returns the contention classification type code list' do
      expect(subject.contention_classification_type_code_list).to eq(mock_list)
    end
  end

  describe '#bgs_classification_ids' do
    let(:mock_list) { [{ clsfcn_id: '1234', end_dt: nil }, { clsfcn_id: '5678', end_dt: '2020-01-01' }] }

    before do
      allow(subject).to receive(:contention_classification_type_code_list).and_return(mock_list)
    end

    it 'returns an array of classification ids' do
      expect(subject.bgs_classification_ids).to eq(%w[1234 5678])
    end
  end
  # rubocop:enable RSpec/SubjectStub

  describe '#validate_form_526_fewer_than_150_disabilities!' do
    context 'when disabilities count is less than or equal to 150' do
      let(:form_attributes) { { 'disabilities' => Array.new(150) { { 'name' => 'PTSD' } } } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_fewer_than_150_disabilities! }.not_to raise_error
      end
    end

    context 'when disabilities count is greater than 150' do
      let(:form_attributes) { { 'disabilities' => Array.new(151) { { 'name' => 'PTSD' } } } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_fewer_than_150_disabilities! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_disability_classification_code!' do
    let(:classification_code) { '1234' }
    let(:expired_code) { '9999' }
    let(:unknown_code) { '8888' }
    let(:today) { Time.zone.today }
    let(:valid_disabilities) do
      [
        { 'classificationCode' => classification_code },
        { 'classificationCode' => nil },
        { 'classificationCode' => '' }
      ]
    end
    let(:form_attributes) { { 'disabilities' => valid_disabilities } }
    let(:contention_list) do
      [
        { clsfcn_id: classification_code, end_dt: nil },
        { clsfcn_id: expired_code, end_dt: (today - 1).to_s }
      ]
    end

    before do
      # Stubbing this because it's a method on the subject that fetches data from BRD
      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive_messages(
        contention_classification_type_code_list: contention_list,
        bgs_classification_ids: contention_list.map { |c|
          c[:clsfcn_id]
        }
      )
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when all classification codes are valid and not expired' do
      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_classification_code! }.not_to raise_error
      end
    end

    context 'when a classification code is not in the BGS list' do
      let(:form_attributes) { { 'disabilities' => [{ 'classificationCode' => unknown_code }] } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_classification_code! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when a classification code is expired' do
      let(:form_attributes) { { 'disabilities' => [{ 'classificationCode' => expired_code }] } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_classification_code! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when classificationCode is nil or blank' do
      let(:form_attributes) { { 'disabilities' => [{ 'classificationCode' => nil }, { 'classificationCode' => '' }] } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_classification_code! }.not_to raise_error
      end
    end
  end

  describe '#validate_form_526_disability_approximate_begin_date!' do
    context 'when disabilities is blank' do
      let(:form_attributes) { { 'disabilities' => [] } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }.not_to raise_error
      end
    end

    context 'when approximateBeginDate is blank' do
      let(:form_attributes) { { 'disabilities' => [{ 'approximateBeginDate' => nil }] } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }.not_to raise_error
      end
    end

    context 'when approximateBeginDate is in the past' do
      let(:form_attributes) { { 'disabilities' => [{ 'approximateBeginDate' => 1.day.ago.to_date.iso8601 }] } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }.not_to raise_error
      end
    end

    context 'when approximateBeginDate is today' do
      let(:form_attributes) { { 'disabilities' => [{ 'approximateBeginDate' => Time.zone.today.iso8601 }] } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when approximateBeginDate is in the future' do
      let(:form_attributes) { { 'disabilities' => [{ 'approximateBeginDate' => 1.day.from_now.to_date.iso8601 }] } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'with multiple disabilities, one with invalid date' do
      let(:form_attributes) do
        {
          'disabilities' => [
            { 'approximateBeginDate' => 1.year.ago.to_date.iso8601 },
            { 'approximateBeginDate' => 1.day.from_now.to_date.iso8601 }
          ]
        }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_approximate_begin_date! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_special_issues!' do
    let(:form_attributes) do
      { 'disabilities' => disabilities, 'serviceInformation' => service_information,
        'disabilityActionType' => disability_action_type }
    end
    let(:service_information) { {} }
    let(:disability_action_type) { nil }

    context 'when disabilities is blank' do
      let(:disabilities) { [] }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context 'when specialIssues is blank' do
      let(:disabilities) { [{ 'specialIssues' => nil }] }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context "when specialIssues includes 'HEPC' and name is 'hepatitis'" do
      let(:disabilities) { [{ 'specialIssues' => ['HEPC'], 'name' => 'hepatitis' }] }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context "when specialIssues includes 'HEPC' and name is not 'hepatitis'" do
      let(:disabilities) { [{ 'specialIssues' => ['HEPC'], 'name' => 'PTSD' }] }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_special_issues! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context "when specialIssues includes 'POW' and confinements is present" do
      let(:disabilities) { [{ 'specialIssues' => ['POW'] }] }
      let(:service_information) { { 'confinements' => ['some confinement'] } }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context "when specialIssues includes 'POW' and confinements is blank" do
      let(:disabilities) { [{ 'specialIssues' => ['POW'] }] }
      let(:service_information) { { 'confinements' => nil } }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_special_issues! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context "when disabilityActionType is 'INCREASE' and specialIssues includes 'EMP'" do
      let(:disabilities) { [{ 'specialIssues' => ['EMP'] }] }
      let(:disability_action_type) { 'INCREASE' }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context "when disabilityActionType is 'INCREASE' and specialIssues includes 'RRD'" do
      let(:disabilities) { [{ 'specialIssues' => ['RRD'] }] }
      let(:disability_action_type) { 'INCREASE' }

      it 'does not raise an error' do
        expect { subject.validate_form_526_special_issues! }.not_to raise_error
      end
    end

    context "when disabilityActionType is 'INCREASE' and specialIssues includes other value" do
      let(:disabilities) { [{ 'specialIssues' => ['OTHER'] }] }
      let(:disability_action_type) { 'INCREASE' }

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_special_issues! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#validate_form_526_disability_unique_names!' do
    context 'when all disability names are unique' do
      let(:form_attributes) do
        { 'disabilities' => [
          { 'name' => 'PTSD' },
          { 'name' => 'Back Pain' },
          { 'name' => 'Hearing Loss' }
        ] }
      end

      it 'does not raise an error' do
        expect { subject.validate_form_526_disability_unique_names! }.not_to raise_error
      end
    end

    context 'when there are duplicate disability names (case-insensitive)' do
      let(:form_attributes) do
        { 'disabilities' => [
          { 'name' => 'PTSD' },
          { 'name' => 'ptsd' },
          { 'name' => 'Back Pain' }
        ] }
      end

      it 'raises an InvalidFieldValue error' do
        expect { subject.validate_form_526_disability_unique_names! }
          .to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#mask_all_but_first_character' do
    it 'returns nil if value is blank' do
      expect(subject.mask_all_but_first_character(nil)).to be_nil
      expect(subject.mask_all_but_first_character('')).to eq('')
    end

    it 'returns the value if it is not a String' do
      expect(subject.mask_all_but_first_character(123)).to eq(123)
      expect(subject.mask_all_but_first_character([])).to eq([])
    end

    it 'returns the value if it is a single character' do
      expect(subject.mask_all_but_first_character('A')).to eq('A')
    end

    it 'masks all but the first character for longer strings' do
      expect(subject.mask_all_but_first_character('PTSD')).to eq('P***')
      expect(subject.mask_all_but_first_character('hepatitis')).to eq('h********')
    end
  end
end
