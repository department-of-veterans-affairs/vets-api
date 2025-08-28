# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::RevisedDisabilityCompensationValidation do
  subject { test_class.new(form_attributes) }

  let(:test_class) do
    Class.new do
      include ClaimsApi::V2::RevisedDisabilityCompensationValidation

      attr_accessor :form_attributes

      def initialize(form_attributes)
        @form_attributes = form_attributes
      end
    end
  end

  let(:base_form_attributes) do
    {
      'serviceInformation' => {
        'servicePeriods' => [
          {
            # serviceBranch intentionally omitted to avoid external service call in base tests
            'activeDutyBeginDate' => '2010-01-01',
            'activeDutyEndDate' => '2020-01-01'
          }
        ]
      }
    }
  end

  let(:form_attributes) { base_form_attributes }

  describe '#validate_form_526_fes_values' do
    context 'with valid data' do
      it 'returns nil when no errors' do
        errors = subject.validate_form_526_fes_values
        expect(errors).to be_nil
      end
    end

    context 'service periods validation' do
      context 'when service periods are missing' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'] = []
          end
        end

        it 'returns no errors (JSON schema will validate)' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when there are more than 100 service periods' do
        let(:form_attributes) do
          periods = Array.new(101) do |i|
            {
              # No serviceBranch to avoid external calls
              'activeDutyBeginDate' => "20#{10 + (i / 12)}-01-01",
              'activeDutyEndDate' => "20#{10 + (i / 12)}-12-31"
            }
          end
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'] = periods
          end
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('must be between 1 and 100 inclusive')
        end
      end

      context 'when dates are out of order' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] = '2020-01-01'
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2010-01-01'
          end
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to eq('activeDutyEndDate (0) needs to be after activeDutyBeginDate.')
        end
      end

      context 'when end date is more than 180 days in future' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = (Date.current + 181.days).to_s
          end
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('more than 180 days in the future')
        end
      end
    end

    context 'reserves national guard validation' do
      context 'with missing obligation dates in v2 structure' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['reservesNationalGuardService'] = {
              'obligationTermsOfService' => {
                # Missing beginDate and endDate
              }
            }
          end
        end

        it 'returns validation errors for missing dates' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to eq(2)
          error_details = errors.map { |e| e[:detail] }
          expect(error_details).to include('Reserves national guard service obligation to date not found')
          expect(error_details).to include('Reserves national guard service obligation from date not found')
        end
      end

      context 'with valid obligation dates in v2 structure' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['reservesNationalGuardService'] = {
              'obligationTermsOfService' => {
                'beginDate' => '2010-01-01',
                'endDate' => '2020-01-01'
              }
            }
          end
        end

        it 'does not return validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end
    end

    context 'error aggregation' do
      context 'with multiple validation errors' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] = '2020-01-01'
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2010-01-01' # Out of order
            # Remove branch to avoid extra error
            attrs['serviceInformation']['servicePeriods'][0].delete('serviceBranch')
          end
        end

        it 'collects and returns all errors together' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to be >= 1

          error_details = errors.map { |e| e[:detail] }
          expect(error_details).to include('activeDutyEndDate (0) needs to be after activeDutyBeginDate.')
        end
      end
    end

    # FES Val Section 5: veteran validations
    context 'veteran validations' do
      # FES Val Section 5.a: homelessness validations - REMOVED (crossed off in FES doc)

      # FES Val Section 5.b: mailingAddress validations
      context 'mailingAddress validation' do
        # USA address validations
        context 'when USA address missing state' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteranIdentification' => {
                'mailingAddress' => {
                  'addressLine1' => '123 Main St',
                  'country' => 'USA',
                  'city' => 'Los Angeles',
                  'zipFirstFive' => '90210'
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/state')
            expect(errors.first[:detail]).to eq('State is required for USA addresses')
          end
        end

        context 'when USA address missing zipFirstFive' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteranIdentification' => {
                'mailingAddress' => {
                  'addressLine1' => '123 Main St',
                  'country' => 'USA',
                  'city' => 'Los Angeles',
                  'state' => 'CA'
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/zipFirstFive')
            expect(errors.first[:detail]).to eq('ZipFirstFive is required for USA addresses')
          end
        end

        # Validation for internationalPostalCode when country is USA
        context 'when USA address has internationalPostalCode' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteranIdentification' => {
                'mailingAddress' => {
                  'addressLine1' => '123 Main St',
                  'country' => 'USA',
                  'city' => 'Los Angeles',
                  'state' => 'CA',
                  'zipFirstFive' => '90210',
                  'internationalPostalCode' => 'SW1A 1AA'
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/internationalPostalCode')
            expect(errors.first[:detail]).to eq('InternationalPostalCode should not be provided for USA addresses')
          end
        end

        # FES Val Section 5.b.vi.2: country must be valid
        context 'when country is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteranIdentification' => {
                'mailingAddress' => {
                  'addressLine1' => '123 Main St',
                  'type' => 'INTERNATIONAL',
                  'city' => 'London',
                  'country' => 'INVALID_COUNTRY',
                  'internationalPostalCode' => 'SW1A 1AA'
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/country')
            expect(errors.first[:detail]).to eq('Provided country is not valid: INVALID_COUNTRY')
          end
        end

        # FES Val Section 5.b.vii.2: BGS service unavailable
        context 'when BGS service is unavailable' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteranIdentification' => {
                'mailingAddress' => {
                  'addressLine1' => '123 Main St',
                  'type' => 'INTERNATIONAL',
                  'city' => 'London',
                  'country' => 'GBR',
                  'internationalPostalCode' => 'SW1A 1AA'
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(nil)
          end

          it 'returns BGS service error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/country')
            expect(errors.first[:title]).to eq('Internal Server Error')
            expect(errors.first[:detail]).to eq('Failed To Obtain Country Types (Request Failed)')
          end
        end
      end

      # FES Val Section 5.c: changeOfAddress validations
      context 'changeOfAddress validation' do
        # FES Val Section 5.c.i: TEMPORARY address requires dates
        context 'when TEMPORARY address missing beginDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'TEMPORARY',
                'country' => 'USA',
                'city' => 'New York',
                'state' => 'NY',
                'zipFirstFive' => '10001',
                'dates' => {
                  'endDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.any? { |e| e[:source] == '/changeOfAddress/dates/beginDate' }).to be true
            matching_error = errors.find { |e| e[:source] == '/changeOfAddress/dates/beginDate' }
            expect(matching_error[:detail]).to eq('beginDate is required for temporary address')
          end
        end

        # FES Val Section 5.c.ii.2: PERMANENT address cannot have endDate
        context 'when PERMANENT address has endDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'PERMANENT',
                'country' => 'USA',
                'city' => 'New York',
                'state' => 'NY',
                'zipFirstFive' => '10001',
                'dates' => {
                  'endDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/changeOfAddress/dates/endDate')
            expect(errors.first[:title]).to eq('Cannot provide endDate')
            expect(errors.first[:detail]).to eq('EndDate cannot be provided for a permanent address.')
          end
        end

        # FES Val Section 5.c.iii.2: beginningDate must be in future for TEMPORARY
        context 'when TEMPORARY address beginDate is in past' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'TEMPORARY',
                'country' => 'USA',
                'city' => 'New York',
                'state' => 'NY',
                'zipFirstFive' => '10001',
                'dates' => {
                  'beginDate' => (Date.current - 1.day).to_s,
                  'endDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:source] == '/changeOfAddress/dates/beginDate' }
            expect(error[:title]).to eq('Invalid beginDate')
            expect(error[:detail]).to eq('BeginDate cannot be in the past: YYYY-MM-DD')
          end
        end

        # FES Val Section 5.c.iv.2: dates must be chronological
        context 'when beginDate is after endDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'TEMPORARY',
                'country' => 'USA',
                'city' => 'New York',
                'state' => 'NY',
                'zipFirstFive' => '10001',
                'dates' => {
                  'beginDate' => (Date.current + 60.days).to_s,
                  'endDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:source] == '/changeOfAddress/dates/beginDate' }
            expect(error).not_to be_nil
            expect(error[:title]).to eq('Invalid beginDate')
            expect(error[:detail]).to eq('BeginDate cannot be after endDate: YYYY-MM-DD')
          end
        end

        # FES Val Section 5.c.v-viii: Address field requirements same as currentMailingAddress
        context 'when changeOfAddress USA missing required fields' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'PERMANENT',
                'country' => 'USA',
                'city' => 'New York'
                # Missing state and zipFirstFive
              }
            )
          end

          before do
            allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.size).to be >= 2

            error_sources = errors.map { |e| e[:source] }
            expect(error_sources).to include('/changeOfAddress/state')
            expect(error_sources).to include('/changeOfAddress/zipFirstFive')
          end
        end
      end

      # Testing error aggregation for veteranIdentification and changeOfAddress validations
      context 'with multiple veteranIdentification and changeOfAddress validation errors' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'country' => 'USA',
                'city' => 'Los Angeles'
                # Missing state and zipFirstFive
              }
            },
            'changeOfAddress' => {
              'typeOfAddressChange' => 'PERMANENT',
              'country' => 'USA',
              'city' => 'New York',
              'addressLine1' => '456 Oak St',
              'dates' => {
                'endDate' => '2025-01-01' # Invalid for permanent
              }
            }
          )
        end

        before do
          allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
        end

        it 'collects all veteranIdentification and changeOfAddress validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to be >= 3 # At least 3 errors expected

          error_sources = errors.map { |e| e[:source] }
          expect(error_sources).to include('/veteranIdentification/mailingAddress/state')
          expect(error_sources).to include('/veteranIdentification/mailingAddress/zipFirstFive')
          expect(error_sources).to include('/changeOfAddress/dates/endDate')
        end
      end
    end
  end
end
