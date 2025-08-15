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
      'claimDate' => Date.current.to_s,
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
      it 'returns empty errors array' do
        errors = subject.validate_form_526_fes_values
        expect(errors).to eq([])
      end
    end

    context 'claim date validation' do
      context 'when claim date is in the future' do
        let(:form_attributes) do
          base_form_attributes.merge('claimDate' => (Date.current + 1.day).to_s)
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('claim date was in the future')
        end
      end

      context 'when claim date has invalid format' do
        let(:form_attributes) do
          base_form_attributes.merge('claimDate' => 'not-a-date')
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to include('Invalid date format')
        end
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
          expect(errors).to eq([])
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
      context 'with missing obligation dates' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['reservesNationalGuardService'] = {
              'unitName' => 'Test Unit'
            }
          end
        end

        it 'returns validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          error_details = errors.map { |e| e[:detail] }
          expect(error_details).to include(
            'The service period is missing a required start date for the obligation terms of service'
          )
          expect(error_details).to include(
            'The service period is missing a required end date for the obligation terms of service'
          )
        end
      end

      context 'with title 10 activation missing anticipated separation date' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['serviceInformation']['servicePeriods'][0]['reservesNationalGuardService'] = {
              'obligationTermOfServiceFromDate' => '2010-01-01',
              'obligationTermOfServiceToDate' => '2020-01-01',
              'title10Activation' => {
                'title10ActivationDate' => '2015-01-01'
              }
            }
          end
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:detail]).to eq('Title 10 activation is missing the anticipated separation date')
        end
      end
    end

    context 'error aggregation' do
      context 'with multiple validation errors' do
        let(:form_attributes) do
          base_form_attributes.tap do |attrs|
            attrs['claimDate'] = (Date.current + 1.day).to_s # Future date
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] = '2020-01-01'
            attrs['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2010-01-01' # Out of order
            # Remove branch to avoid extra error
            attrs['serviceInformation']['servicePeriods'][0].delete('serviceBranch')
          end
        end

        it 'collects and returns all errors together' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to eq(2)

          error_details = errors.map { |e| e[:detail] }
          expect(error_details).to include(match(/claim date was in the future/))
          expect(error_details).to include('activeDutyEndDate (0) needs to be after activeDutyBeginDate.')
        end
      end
    end

    # FES Val Section 5: veteran validations
    context 'veteran validations' do
      # FES Val Section 5.a: homelessness validations
      context 'homelessness validation' do
        # FES Val Section 5.a.i: otherLivingSituation - When "OTHER" is selected, value needed
        context 'when currentlyHomeless has OTHER without description' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'homelessness' => {
                  'currentlyHomeless' => {
                    'homelessSituationOptions' => 'OTHER',
                    'otherDescription' => nil
                  },
                  'pointOfContact' => 'John Doe'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/homelessness/currentlyHomeless/otherDescription')
            expect(errors.first[:detail]).to eq('otherDescription is required when homelessSituationOptions is OTHER')
          end
        end

        # FES Val Section 5.a.ii: currentlyHomeless or homelessnessRisk - only one allowed
        context 'when both currentlyHomeless and homelessnessRisk are provided' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'homelessness' => {
                  'currentlyHomeless' => { 'homelessSituationOptions' => 'FLEEING' },
                  'homelessnessRisk' => { 'livingSituationOptions' => 'SHELTER' },
                  'pointOfContact' => 'John Doe'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/homelessness/')
            expect(errors.first[:detail]).to include(
              "Must define only one of 'currentlyHomeless' or 'homelessnessRisk'"
            )
          end
        end

        # FES Val Section 5.a.iii: pointOfContact must be null if no homelessness info
        context 'when pointOfContact provided without homelessness attributes' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'homelessness' => {
                  'pointOfContact' => 'John Doe'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/homelessness/')
            expect(errors.first[:detail]).to include("If 'pointOfContact' is defined")
          end
        end

        # FES Val Section 5.a.iv: pointOfContact required if homeless info provided
        context 'when currentlyHomeless provided without pointOfContact' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'homelessness' => {
                  'currentlyHomeless' => { 'homelessSituationOptions' => 'FLEEING' }
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/homelessness/')
            expect(errors.first[:detail]).to include("'pointOfContact' is required")
          end
        end
      end

      # FES Val Section 5.b: currentMailingAddress validations
      context 'currentMailingAddress validation' do
        # FES Val Section 5.b.ii: city, state and zipCode required for DOMESTIC
        context 'when DOMESTIC address missing city' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
                  'type' => 'DOMESTIC',
                  'state' => 'CA',
                  'zipFirstFive' => '90210'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/city')
            expect(errors.first[:detail]).to eq('City is required for domestic address')
          end
        end

        context 'when DOMESTIC address missing state' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
                  'type' => 'DOMESTIC',
                  'city' => 'Los Angeles',
                  'zipFirstFive' => '90210'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/state')
            expect(errors.first[:detail]).to eq('State is required for domestic address')
          end
        end

        # FES Val Section 5.b.iii: city and country required for INTERNATIONAL
        context 'when INTERNATIONAL address missing country' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
                  'type' => 'INTERNATIONAL',
                  'city' => 'London',
                  'internationalPostalCode' => 'SW1A 1AA'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/country')
            expect(errors.first[:detail]).to eq('Country is required for international address')
          end
        end

        # FES Val Section 5.b.v: internationalPostalCode required for INTERNATIONAL
        context 'when INTERNATIONAL address missing postal code' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
                  'type' => 'INTERNATIONAL',
                  'city' => 'London',
                  'country' => 'GBR'
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
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/internationalPostalCode')
            expect(errors.first[:detail]).to eq('InternationalPostalCode is required for international address')
          end
        end

        # FES Val Section 5.b.iv: Military address field requirements
        context 'when MILITARY address missing militaryPostOfficeTypeCode' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
                  'type' => 'MILITARY',
                  'militaryStateCode' => 'AA',
                  'zipFirstFive' => '34004'
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/militaryPostOfficeTypeCode')
            expect(errors.first[:detail]).to eq('MilitaryPostOfficeTypeCode is required for military address')
          end
        end

        # FES Val Section 5.b.vi: country must be valid
        context 'when country is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'currentMailingAddress' => {
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
            expect(errors.first[:source]).to eq('/veteran/currentMailingAddress/country')
            expect(errors.first[:detail]).to eq('Provided country is not valid: INVALID_COUNTRY')
          end
        end
      end

      # FES Val Section 5.c: changeOfAddress validations
      context 'changeOfAddress validation' do
        # FES Val Section 5.c.i: TEMPORARY address requires dates
        context 'when TEMPORARY address missing beginningDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'changeOfAddress' => {
                  'addressChangeType' => 'TEMPORARY',
                  'type' => 'DOMESTIC',
                  'city' => 'New York',
                  'state' => 'NY',
                  'zipFirstFive' => '10001',
                  'endingDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.any? { |e| e[:source] == '/veteran/changeOfAddress/beginningDate' }).to be true
            matching_error = errors.find { |e| e[:source] == '/veteran/changeOfAddress/beginningDate' }
            expect(matching_error[:detail]).to eq('beginningDate is required for temporary address')
          end
        end

        # FES Val Section 5.c.ii: PERMANENT address cannot have endingDate
        context 'when PERMANENT address has endingDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'changeOfAddress' => {
                  'addressChangeType' => 'PERMANENT',
                  'type' => 'DOMESTIC',
                  'city' => 'New York',
                  'state' => 'NY',
                  'zipFirstFive' => '10001',
                  'endingDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/veteran/changeOfAddress/endingDate')
            expect(errors.first[:detail]).to eq('endingDate cannot be provided for permanent address')
          end
        end

        # FES Val Section 5.c.iii: beginningDate must be in future for TEMPORARY
        context 'when TEMPORARY address beginningDate is in past' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'changeOfAddress' => {
                  'addressChangeType' => 'TEMPORARY',
                  'type' => 'DOMESTIC',
                  'city' => 'New York',
                  'state' => 'NY',
                  'zipFirstFive' => '10001',
                  'beginningDate' => (Date.current - 1.day).to_s,
                  'endingDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.any? do |e|
              e[:detail] == 'beginningDate cannot be in the past for temporary address'
            end).to be true
          end
        end

        # FES Val Section 5.c.iv: dates must be chronological
        context 'when beginningDate is after endingDate' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'changeOfAddress' => {
                  'addressChangeType' => 'TEMPORARY',
                  'type' => 'DOMESTIC',
                  'city' => 'New York',
                  'state' => 'NY',
                  'zipFirstFive' => '10001',
                  'beginningDate' => (Date.current + 60.days).to_s,
                  'endingDate' => (Date.current + 30.days).to_s
                }
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.any? { |e| e[:detail] == 'beginningDate must be before endingDate' }).to be true
          end
        end

        # FES Val Section 5.c.v-viii: Address field requirements same as currentMailingAddress
        context 'when changeOfAddress DOMESTIC missing required fields' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'veteran' => {
                'changeOfAddress' => {
                  'addressChangeType' => 'PERMANENT',
                  'type' => 'DOMESTIC',
                  'city' => 'New York'
                  # Missing state and zipFirstFive
                }
              }
            )
          end

          it 'returns validation errors for missing fields' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.size).to be >= 2

            error_sources = errors.map { |e| e[:source] }
            expect(error_sources).to include('/veteran/changeOfAddress/state')
            expect(error_sources).to include('/veteran/changeOfAddress/zipFirstFive')
          end
        end
      end

      # Testing error aggregation for veteran validations
      context 'with multiple veteran validation errors' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteran' => {
              'homelessness' => {
                'currentlyHomeless' => { 'homelessSituationOptions' => 'FLEEING' }
                # Missing pointOfContact
              },
              'currentMailingAddress' => {
                'type' => 'DOMESTIC'
                # Missing required fields
              },
              'changeOfAddress' => {
                'addressChangeType' => 'PERMANENT',
                'endingDate' => '2025-01-01' # Invalid for permanent
              }
            }
          )
        end

        it 'collects all veteran validation errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to be >= 4 # At least 4 errors expected

          error_sources = errors.map { |e| e[:source] }
          expect(error_sources).to include('/veteran/homelessness/')
          expect(error_sources).to include('/veteran/currentMailingAddress/city')
          expect(error_sources).to include('/veteran/changeOfAddress/endingDate')
        end
      end
    end
  end
end
