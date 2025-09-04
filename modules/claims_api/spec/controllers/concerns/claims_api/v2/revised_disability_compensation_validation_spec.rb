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
    end

    context 'service information validations' do
      context 'when invalid separation location code is provided' do
        let(:form_attributes) do
          {
            'serviceInformation' => {
              'separationLocationCode' => 'INVALID_CODE',
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2010-01-01',
                  'activeDutyEndDate' => '2020-01-01'
                }
              ]
            }
          }
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/serviceInformation')
          expect(errors.first[:detail]).to include('Provided separation location code is not valid: INVALID_CODE')
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
            expect(errors.first[:detail]).to include('obligationTermsOfService is missing or blank')
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

    # FES Val Section 5.b: mailingAddress validations - PR 1
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
          expect(errors.first[:title]).to eq('Missing state')
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
          expect(errors.first[:title]).to eq('Missing zipFirstFive')
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
          expect(errors.first[:title]).to eq('Invalid field')
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

    # FES Val Section 5.b: mailingAddress validations - PR 2 Country Validation
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

      context 'when BGS service is unavailable' do
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

        it 'returns BGS service error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/veteranIdentification/mailingAddress/country')
          expect(errors.first[:title]).to eq('Internal Server Error')
          expect(errors.first[:detail]).to eq('Failed To Obtain Country Types (Request Failed)')
        end
      end

      context 'when valid country is provided' do
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
          allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
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
          expect(errors.first[:title]).to eq('Missing internationalPostalCode')
          expect(errors.first[:detail]).to eq('InternationalPostalCode is required for non-USA addresses')
        end
      end

      context 'when USA address does not have internationalPostalCode' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'veteranIdentification' => {
              'mailingAddress' => {
                'addressLine1' => '123 Main St',
                'city' => 'Los Angeles',
                'country' => 'USA',
                'state' => 'CA',
                'zipFirstFive' => '90210'
              }
            }
          )
        end

        before do
          allow_any_instance_of(described_class).to receive(:valid_countries).and_return(%w[USA GBR CAN])
        end

        it 'returns no errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end
    end
  end
end
