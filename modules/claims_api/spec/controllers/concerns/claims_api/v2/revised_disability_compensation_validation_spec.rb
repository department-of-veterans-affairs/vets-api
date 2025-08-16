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
    # Testing with all valid data - no validation errors expected
    context 'with valid data' do
      it 'returns empty errors array' do
        errors = subject.validate_form_526_fes_values
        expect(errors).to eq([])
      end
    end

    # FES Val Section 2.1: claimDate must be equal to or earlier than today's date
    context 'claim date validation' do
      # FES Val Section 2.1: Future dates not allowed
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

      # FES Val Section 2.1: Date format validation (ISO8601)
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

    # FES Val Section 2.4.b: servicePeriods validations
    context 'service periods validation' do
      # FES Val Section 2.4.b: servicePeriods element required
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

      # FES Val Section 2.4.b: Maximum 100 service periods allowed
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

      # FES Val Section 2.4.b.ii: Start and end dates must be in chronological order
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

      # FES Val Section 2.4.b.iv: activeDutyEndDate cannot be more than 180 days in future
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

    # FES Val Section 2.4.c: reservesNationalGuardService validation rules
    context 'reserves national guard validation' do
      # FES Val Section 2.4.c.i: Requires obligationTermOfServiceFromDate and ToDate
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

      # FES Val Section 2.4.c.iii: title10Activation requires anticipatedSeparationDate
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

    # Testing that multiple validation errors are collected and returned together
    context 'error aggregation' do
      # Testing error aggregation for multiple issues
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

    # Test patterns adapted from existing V2 526_spec.rb disability validations
    # FES Val Section 7: Disabilities validations
    context 'disabilities validation' do
      # FES Val Section 7.a: Disability name is required
      context 'when disability name is missing' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/name')
          expect(errors.first[:detail]).to eq('The disability name at index 0 is required')
        end
      end

      # FES Val Section 7.k: classificationCode must match BRD disabilities list
      context 'when disability classification code is invalid' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Tinnitus',
                'classificationCode' => '99999',
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        before do
          allow_any_instance_of(ClaimsApi::BRD).to receive(:disabilities).and_return(
            [
              { id: 1234, name: 'Tinnitus' },
              { id: 5678, name: 'Hearing Loss' }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/classificationCode')
          expect(errors.first[:detail]).to eq('The classification code for disability 0 is not valid')
        end
      end

      # FES Val Section 7.k: classificationCode must be active (not expired)
      context 'when disability classification code is expired' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Tinnitus',
                'classificationCode' => '1234',
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        before do
          allow_any_instance_of(ClaimsApi::BRD).to receive(:disabilities).and_return(
            [
              { id: 1234, name: 'Tinnitus', endDateTime: (Date.current - 1.day).to_s }
            ]
          )
        end

        it 'returns validation error for expired code' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/classificationCode')
          expect(errors.first[:detail]).to eq('The classification code is no longer active')
        end
      end

      # FES Val Section 7.t: approximateBeginDate must be in the past
      context 'when disability approximate date is in the future' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Tinnitus',
                'approximateDate' => (Date.current + 1.day).to_s,
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/approximateDate')
          expect(errors.first[:detail]).to eq('Approximate begin date for disability 0 cannot be in the future')
        end
      end

      # FES Val Section 7.r-s: Date format validation for approximateBeginDate
      context 'when disability approximate date has invalid format' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Tinnitus',
                'approximateDate' => 'invalid-date',
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/approximateDate')
          expect(errors.first[:detail]).to eq('Invalid date format for disability 0 approximateDate')
        end
      end

      # FES Val Section 7: serviceRelevance required if disabilityActionType is NEW
      context 'when NEW disability is missing service relevance' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'Tinnitus',
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/serviceRelevance')
          expect(errors.first[:detail]).to eq('Service relevance is required for disability 0 when action type is NEW')
        end
      end

      # FES Val Section 7.w: POW special issue requires valid confinements
      context 'when POW special issue is selected without confinements' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'specialIssues' => ['POW'],
                'serviceRelevance' => 'Service connected'
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/specialIssues')
          expect(errors.first[:detail]).to eq('Confinements are required when special issue POW is selected')
        end
      end

      # FES Val Section 7.u: POW special issue cannot be used with INCREASE action type
      context 'when POW special issue with INCREASE action type' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'activeDutyBeginDate' => '2010-01-01',
                  'activeDutyEndDate' => '2020-01-01'
                }
              ],
              'confinements' => [
                {
                  'confinementBeginDate' => '2015-01-01',
                  'confinementEndDate' => '2015-06-01'
                }
              ]
            },
            'disabilities' => [
              {
                'name' => 'PTSD',
                'disabilityActionType' => 'INCREASE',
                'specialIssues' => ['POW']
              }
            ]
          )
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities/0/disabilityActionType')
          expect(errors.first[:detail]).to eq(
            'Disability action type cannot be INCREASE when special issue POW is selected'
          )
        end
      end

      # FES Val Section 7.y: Secondary disabilities validation rules
      context 'secondary disabilities validation' do
        # FES Val Section 7.y.iii: secondaryDisabilities required if disabilityActionType=NONE
        context 'when action type is NONE without secondary disabilities' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Tinnitus',
                  'disabilityActionType' => 'NONE'
                }
              ]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/secondaryDisabilities')
            expect(errors.first[:detail]).to eq(
              'Secondary disabilities are required when disability action type is NONE'
            )
          end
        end

        # FES Val Section 7.y: Secondary disability must have required fields
        context 'when secondary disability has neither name nor classification code' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Tinnitus',
                  'disabilityActionType' => 'NEW',
                  'serviceRelevance' => 'Service connected',
                  'secondaryDisabilities' => [
                    {
                      'approximateDate' => '2020-01-01'
                    }
                  ]
                }
              ]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/secondaryDisabilities/0/name')
            expect(errors.first[:detail]).to eq('Secondary disability must have either name or classification code')
          end
        end

        # FES Val Section 7.y.ii: name must match regex pattern for SECONDARY disability
        context 'when secondary disability name has invalid format' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Tinnitus',
                  'disabilityActionType' => 'NEW',
                  'serviceRelevance' => 'Service connected',
                  'secondaryDisabilities' => [
                    {
                      'name' => '@@@Invalid###Name@@@'
                    }
                  ]
                }
              ]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/secondaryDisabilities/0/name')
            expect(errors.first[:detail]).to eq(
              'Secondary disability name has invalid format or exceeds 255 characters'
            )
          end
        end

        # FES Val Section 7.y.i: classificationCode must be valid for SECONDARY disabilities
        context 'when secondary disability classification code is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Tinnitus',
                  'disabilityActionType' => 'NEW',
                  'serviceRelevance' => 'Service connected',
                  'secondaryDisabilities' => [
                    {
                      'name' => 'Hearing Loss',
                      'classificationCode' => '99999'
                    }
                  ]
                }
              ]
            )
          end

          before do
            allow_any_instance_of(ClaimsApi::BRD).to receive(:disabilities).and_return(
              [
                { id: 1234, name: 'Tinnitus' }
              ]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/secondaryDisabilities/0/classificationCode')
            expect(errors.first[:detail]).to eq(
              'Secondary disability classification code is not valid'
            )
          end
        end

        # FES Val Section 7.y.vii: approximateBeginDate must be in past for secondary disabilities
        context 'when secondary disability approximate date is in the future' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                {
                  'name' => 'Tinnitus',
                  'disabilityActionType' => 'NEW',
                  'serviceRelevance' => 'Service connected',
                  'secondaryDisabilities' => [
                    {
                      'name' => 'Hearing Loss',
                      'approximateDate' => (Date.current + 1.day).to_s
                    }
                  ]
                }
              ]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/secondaryDisabilities/0/approximateDate')
            expect(errors.first[:detail]).to eq(
              'Secondary disability approximate date cannot be in the future'
            )
          end
        end
      end

      # Testing error aggregation for multiple disability validation errors
      context 'with multiple disability errors' do
        let(:form_attributes) do
          base_form_attributes.merge(
            'disabilities' => [
              {
                'disabilityActionType' => 'NEW' # Missing name and service relevance
              },
              {
                'name' => 'Tinnitus',
                'approximateDate' => (Date.current + 1.day).to_s, # Future date
                'disabilityActionType' => 'NEW'
              }
            ]
          )
        end

        it 'collects all disability errors' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.size).to be >= 3

          error_sources = errors.map { |e| e[:source] }
          expect(error_sources).to include('/disabilities/0/name')
          expect(error_sources).to include('/disabilities/0/serviceRelevance')
          expect(error_sources).to include('/disabilities/1/approximateDate')
        end
      end
    end
  end
end
