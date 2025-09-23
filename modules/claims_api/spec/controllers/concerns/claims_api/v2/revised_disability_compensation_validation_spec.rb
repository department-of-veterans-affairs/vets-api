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
            'activeDutyBeginDate' => '2010-01-01',
            'activeDutyEndDate' => '2020-01-01'
          }
        ]
      }
    }
  end

  let(:form_attributes) { base_form_attributes }

  describe '#validate_form_526_fes_values' do
    context 'when form_attributes is empty' do
      let(:form_attributes) { {} }

      it 'returns an empty array' do
        expect(subject.validate_form_526_fes_values).to eq([])
      end
    end

    context 'when claimDate is provided' do
      context 'when claimDate is in the future' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'claimDate' => (Date.current + 1.day).to_s
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:title]).to eq('Bad Request')
          expect(errors.first[:detail]).to match(/claim date was in the future/)
        end
      end

      context 'when claimDate is today or in the past' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'claimDate' => Date.current.to_s
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when claimDate is in the past' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'claimDate' => (Date.current - 30.days).to_s
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when claimDate has invalid format' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'claimDate' => 'invalid-date'
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:title]).to eq('Bad Request')
          expect(errors.first[:detail]).to eq('Invalid date format for claimDate')
        end
      end
    end

    context 'when claimDate is not provided' do
      let(:form_attributes) do
        base_form_attributes.except('claimDate')
      end

      it 'returns no errors (optional field)' do
        errors = subject.validate_form_526_fes_values
        expect(errors).to be_nil
      end
    end

    context 'service information validations' do
      context 'when invalid separation location code is provided' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2010-01-01',
                  'activeDutyEndDate' => '2020-01-01',
                  'separationLocationCode' => 'INVALID_CODE'
                }
              ]
            }
          }
        end

        before do
          allow_any_instance_of(described_class).to receive(:retrieve_separation_locations)
            .and_return([{ id: 'VALID_CODE' }])
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/serviceInformation/servicePeriods/0/separationLocationCode')
          expect(errors.first[:detail])
            .to include('The separation location code (0) for the claimant is not a valid value')
        end
      end

      context 'when service periods have invalid dates' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2020-01-01',
                  'activeDutyEndDate' => '2010-01-01'
                }
              ]
            }
          }
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('activeDutyEndDate (0) needs to be after activeDutyBeginDate')
        end
      end

      context 'when service period end date is more than 180 days in the future' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2010-01-01',
                  'activeDutyEndDate' => (Date.current + 181.days).to_s
                }
              ]
            }
          }
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('more than 180 days in the future')
        end
      end

      context 'reserves national guard validations' do
        context 'when missing obligation dates' do
          let(:form_attributes) do
            {
              'serviceInformation' => {
                'servicePeriods' => [
                  {
                    'activeDutyBeginDate' => '2010-01-01',
                    'activeDutyEndDate' => '2020-01-01',
                    'reservesNationalGuardService' => {
                      'unitName' => 'Test Unit'
                      # Missing obligationTermsOfService
                    }
                  }
                ]
              }
            }
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:detail])
              .to include('The service period is missing a required start date for the obligation terms of service')
          end
        end
      end

      context 'when both claimDate and service period dates are invalid' do
        let(:form_attributes) do
          {
            'claimDate' => (Date.current + 1.day).to_s,
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2020-01-01',
                  'activeDutyEndDate' => '2010-01-01'
                }
              ]
            }
          }
        end

        it 'returns multiple validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to eq(2)

          error_details = errors.map { |e| e[:detail] }
          expect(error_details).to include(match(/claim date was in the future/))
          expect(error_details).to include('activeDutyEndDate (0) needs to be after activeDutyBeginDate.')
        end
      end
    end

    # FES Val Section 5.b: mailingAddress USA field validations
    context 'mailingAddress USA validation' do
      before do
        allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
      end

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

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/state')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
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

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/zipFirstFive')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('ZipFirstFive is required for USA addresses')
        end
      end

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

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/internationalPostalCode')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('InternationalPostalCode should not be provided for USA addresses')
        end
      end

      context 'when USA address has all required fields' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'country' => 'USA',
                'city' => 'Los Angeles',
                'state' => 'CA',
                'zipFirstFive' => '90210'
              }
            }
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when non-USA address does not require state or zip' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'country' => 'GBR',
                'city' => 'London',
                'internationalPostalCode' => 'SW1A 1AA'
              }
            }
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when USA address missing multiple required fields' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'country' => 'USA',
                'city' => 'Los Angeles',
                'internationalPostalCode' => 'SW1A 1AA'
              }
            }
          )
        end

        it 'returns all validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to eq(3)

          error_sources = errors.map { |e| e[:source] }
          expect(error_sources).to include('/veteranIdentification/mailingAddress/state')
          expect(error_sources).to include('/veteranIdentification/mailingAddress/zipFirstFive')
          expect(error_sources).to include('/veteranIdentification/mailingAddress/internationalPostalCode')
        end
      end
    end

    # FES Val Section 5.b.iii: mailingAddress INTERNATIONAL field validations
    context 'mailingAddress INTERNATIONAL validation' do
      before do
        allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
      end

      context 'when INTERNATIONAL address missing city' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 High St',
                'country' => 'GBR',
                'internationalPostalCode' => 'SW1A 1AA'
                # Missing city
              }
            }
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/city')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('City is required')
        end
      end

      context 'when INTERNATIONAL address missing country' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 High St',
                'city' => 'London',
                'internationalPostalCode' => 'SW1A 1AA'
                # Missing country
              }
            }
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          # Country validation would be checked first in the international validation
          expect(errors.any? { |e| e[:source] == '/veteranIdentification/mailingAddress/country' }).to be true
          expect(errors.any? { |e| e[:title] == 'Unprocessable Entity' }).to be true
        end
      end

      context 'when INTERNATIONAL address has all required fields' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 High St',
                'city' => 'London',
                'country' => 'GBR',
                'internationalPostalCode' => 'SW1A 1AA'
              }
            }
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end
    end

    # FES Val Section 5.b: mailingAddress country and postal code validations
    context 'mailingAddress country validation' do
      context 'when country is invalid' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
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
          expect(errors.first[:title]).to eq('Invalid country')
          expect(errors.first[:detail]).to eq('Provided country is not valid: INVALID_COUNTRY')
        end
      end

      context 'when BRD service is unavailable' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
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

        it 'returns BRD service error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/country')
          expect(errors.first[:title]).to eq('Internal Server Error')
          expect(errors.first[:detail]).to eq('Failed To Obtain Country Types (Request Failed)')
        end
      end

      # FES Val Section 5.b.v: internationalPostalCode validations
      context 'when non-USA address missing internationalPostalCode' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'city' => 'London',
                'country' => 'GBR'
                # internationalPostalCode is missing
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
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('InternationalPostalCode is required for non-USA addresses')
        end
      end
    end

    # FES Val Section 5.c: changeOfAddress date validations
    context 'changeOfAddress date validations' do
      # FES Val Section 5.c.i: TEMPORARY address requires dates
      context 'when TEMPORARY address missing beginDate' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '456 New St',
              'city' => 'New York',
              'country' => 'USA',
              'state' => 'NY',
              'zipFirstFive' => '10001',
              'dates' => {
                'endDate' => '2025-12-31'
              }
            }
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/changeOfAddress/dates/beginDate')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('beginningDate is required for temporary address')
        end
      end

      context 'when TEMPORARY address missing endDate' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '456 New St',
              'city' => 'New York',
              'country' => 'USA',
              'state' => 'NY',
              'zipFirstFive' => '10001',
              'dates' => {
                'beginDate' => '2025-01-01'
              }
            }
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/changeOfAddress/dates/endDate')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('EndingDate is required for temporary address')
        end
      end

      # FES Val Section 5.c.ii: PERMANENT address cannot have endDate
      context 'when PERMANENT address has endDate' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'PERMANENT',
              'addressLine1' => '456 New St',
              'city' => 'New York',
              'country' => 'USA',
              'state' => 'NY',
              'zipFirstFive' => '10001',
              'dates' => {
                'beginDate' => '2025-01-01',
                'endDate' => '2025-12-31'
              }
            }
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/changeOfAddress/dates/endDate')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('EndingDate cannot be provided for a permanent address')
        end
      end

      context 'when PERMANENT address has no endDate' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'PERMANENT',
              'addressLine1' => '456 New St',
              'city' => 'New York',
              'country' => 'USA',
              'state' => 'NY',
              'zipFirstFive' => '10001',
              'dates' => {
                'beginDate' => '2025-01-01'
              }
            }
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      context 'when TEMPORARY address has both dates' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '456 New St',
              'city' => 'New York',
              'country' => 'USA',
              'state' => 'NY',
              'zipFirstFive' => '10001',
              'dates' => {
                'beginDate' => (Date.current + 10.days).to_s,
                'endDate' => (Date.current + 30.days).to_s
              }
            }
          )
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end

      # FES Val Section 5.c.iii-iv: Date logic validations
      context 'when TEMPORARY address has beginDate in the past' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '123 Main St',
              'city' => 'Portland',
              'country' => 'USA',
              'state' => 'OR',
              'zipFirstFive' => '97201',
              'dates' => {
                'beginDate' => (Date.current - 10.days).to_s,
                'endDate' => (Date.current + 30.days).to_s
              }
            }
          )
        end

        it 'returns validation error for past beginDate' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.any? do |e|
            e[:source] == '/changeOfAddress/dates/beginDate' &&
              e[:title] == 'Invalid beginningDate' &&
              e[:detail].include?('BeginningDate cannot be in the past')
          end).to be true
        end
      end

      context 'when TEMPORARY address dates are not in chronological order' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'changeOfAddress' => {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '123 Main St',
              'city' => 'Portland',
              'country' => 'USA',
              'state' => 'OR',
              'zipFirstFive' => '97201',
              'dates' => {
                'beginDate' => (Date.current + 30.days).to_s,
                'endDate' => (Date.current + 10.days).to_s
              }
            }
          )
        end

        it 'returns validation error for invalid date order' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.any? { |e| e[:detail].include?('BeginningDate cannot be after endingDate') }).to be true
        end
      end

      # FES Val Section 5.c.v-viii: changeOfAddress field validations
      context 'changeOfAddress field validations' do
        context 'USA address (5.c.v)' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'PERMANENT',
                'country' => 'USA',
                'addressLine1' => '123 Main St',
                'dates' => { 'beginDate' => (Date.current + 10.days).to_s }
                # Missing city, state, zipFirstFive
              }
            )
          end

          it 'validates required fields for USA addresses' do
            errors = subject.validate_form_526_fes_values
            expect(errors.size).to eq(3)
            expect(errors.map do |e|
              e[:source]
            end).to contain_exactly('/changeOfAddress/city', '/changeOfAddress/state', '/changeOfAddress/zipFirstFive')
          end
        end

        context 'Non-USA address (5.c.vi & 5.c.viii)' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'changeOfAddress' => {
                'typeOfAddressChange' => 'PERMANENT',
                'country' => 'GBR',
                'addressLine1' => '123 High St',
                'dates' => { 'beginDate' => (Date.current + 10.days).to_s }
                # Missing city, internationalPostalCode
              }
            )
          end

          it 'validates required fields for international addresses' do
            errors = subject.validate_form_526_fes_values
            expect(errors.size).to eq(2)
            expect(errors.map do |e|
              e[:detail]
            end).to contain_exactly('City is required', 'InternationalPostalCode is required')
          end
        end
      end
    end

    # FES Val Section 7: Disability action type and name validations
    context 'disability action type and name validations' do
      context 'when disability has actionType NONE' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'PTSD',
                'disabilityActionType' => 'NONE'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/disabilityActionType')
          expect(errors.first[:title]).to eq('Unprocessable Entity')
          expect(errors.first[:detail]).to eq('The request failed disability validation: ' \
                                              'The disability Action Type of "NONE" is not currently supported.')
        end
      end

      context 'when disability name format validation for NEW disabilities' do
        context 'with valid name format' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Post-Traumatic Stress Disorder (PTSD)',
                  'disabilityActionType' => 'NEW'
                }
              ]
            )
          end

          it 'returns no errors' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_nil
          end
        end

        context 'with invalid name starting with space' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => ' PTSD',
                  'disabilityActionType' => 'NEW'
                }
              ]
            )
          end

          it 'returns no custom validation error (schema handles format)' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_nil
          end
        end

        context 'with invalid characters' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'PTSD @ Location',
                  'disabilityActionType' => 'NEW'
                }
              ]
            )
          end

          it 'returns no custom validation error (schema handles format)' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_nil
          end
        end

        context 'with INCREASE actionType (should not validate format)' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => ' Invalid Format',
                  'disabilityActionType' => 'INCREASE',
                  'ratedDisabilityId' => '123',
                  'diagnosticCode' => '9999'
                }
              ]
            )
          end

          it 'returns no errors (format validation only for NEW)' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_nil
          end
        end
      end

      context 'with multiple disabilities having different issues' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Valid Name',
                'disabilityActionType' => 'NEW'
              },
              {
                'name' => 'Another condition',
                'disabilityActionType' => 'NONE'
              },
              {
                'name' => 'Invalid @ Name',
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'returns error only for NONE disability (format handled by schema)' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to eq(1)

          # Check for NONE error on second disability
          none_error = errors.find { |e| e[:source] == '/disabilities/1/disabilityActionType' }
          expect(none_error[:detail]).to include('NONE')

          # Format error for third disability is handled by schema, not custom validation
        end
      end
    end
  end
end
