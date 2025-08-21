# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::RevisedDisabilityCompensationValidation do
  subject { test_class.new(form_attributes) }

  let(:test_class) do
    Class.new do
      include ClaimsApi::V2::RevisedDisabilityCompensationValidation
      include ClaimsApi::V2::DisabilityCompensationSharedServiceModule

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
      it 'returns nil when no errors' do
        errors = subject.validate_form_526_fes_values
        expect(errors).to be_nil
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

    # FES Val Section 7: disabilities validations
    context 'disabilities validations' do
      context 'when disabilities array is empty' do
        let(:form_attributes) do
          base_form_attributes.merge('disabilities' => [])
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          expect(errors.first[:source]).to eq('/disabilities')
          expect(errors.first[:detail]).to eq('List of disabilities must be provided')
        end
      end

      context 'when disabilities exceed 150' do
        let(:form_attributes) do
          disabilities = Array.new(151) { |i| { 'name' => "Disability #{i}" } }
          base_form_attributes.merge('disabilities' => disabilities)
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          error = errors.find { |e| e[:detail].include?('must be between 1 and 150') }
          expect(error).not_to be_nil
        end
      end

      context 'NONE with secondary disabilities' do
        context 'when NONE has secondary but no diagnosticCode' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NONE',
                'secondaryDisabilities' => [{ 'name' => 'Anxiety' }]
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('NONE" is not currently supported') }
            expect(error).not_to be_nil
          end
        end
      end

      context 'REOPEN validation' do
        context 'when disabilityActionType is REOPEN' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'REOPEN'
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('REOPEN" is not currently supported') }
            expect(error).not_to be_nil
          end
        end
      end

      context 'disability name validations' do
        context 'when name is missing' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'disabilityActionType' => 'NEW'
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            expect(errors.first[:source]).to eq('/disabilities/0/name')
            expect(errors.first[:detail]).to include('disability name (0) is required')
          end
        end

        context 'when name exceeds 255 characters' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'A' * 256,
                'disabilityActionType' => 'NEW'
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('less than 256 characters') }
            expect(error).not_to be_nil
          end
        end

        context 'when NEW disability name has invalid format' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD!!!',
                'disabilityActionType' => 'NEW'
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('does not match the expected format') }
            expect(error).not_to be_nil
          end
        end
      end

      context 'approximateBeginDate validations' do
        context 'when date is in future' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'approximateBeginDate' => (Date.current + 30).to_s
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('must be in the past') }
            expect(error).not_to be_nil
          end
        end

        context 'when month is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'approximateBeginDate' => '2020-13-01'
              }]
            )
          end

          it 'returns month validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail] == 'The month is not a valid value' }
            expect(error).not_to be_nil
          end
        end

        context 'when day is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'approximateBeginDate' => '2020-02-30'
              }]
            )
          end

          it 'returns day validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail] == 'The day is not a valid value' }
            expect(error).not_to be_nil
          end
        end

        context 'when date is invalid' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'approximateBeginDate' => 'invalid-date'
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            # This will fail the parse_date_safely check
            expect(errors).not_to be_nil
          end
        end
      end

      context 'special issues validations' do
        context 'when INCREASE has invalid special issue' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'INCREASE',
                'diagnosticCode' => '9411',
                'ratedDisabilityId' => '123',
                'specialIssues' => ['ALS']
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('cannot be added to a primary disability after') }
            expect(error).not_to be_nil
          end
        end

        context 'when HEPC without Hepatitis' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'Back Pain',
                'disabilityActionType' => 'NEW',
                'specialIssues' => ['HEPC']
              }]
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('HEPC can only exist for the disability Hepatitis') }
            expect(error).not_to be_nil
          end
        end

        context 'when POW without confinements' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [{
                'name' => 'PTSD',
                'disabilityActionType' => 'NEW',
                'specialIssues' => ['POW']
              }],
              'serviceInformation' => {
                'servicePeriods' => [{
                  'activeDutyBeginDate' => '2000-01-01',
                  'activeDutyEndDate' => '2005-01-01'
                }]
              }
            )
          end

          it 'returns validation error' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find do |e|
              e[:detail].include?('prisoner of war must have at least one period of confinement')
            end
            expect(error).not_to be_nil
          end
        end
      end

      context 'duplicate disability names' do
        context 'when disabilities have duplicate names' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                { 'name' => 'PTSD', 'disabilityActionType' => 'NEW' },
                { 'name' => 'Back Pain', 'disabilityActionType' => 'NEW' },
                { 'name' => 'PTSD', 'disabilityActionType' => 'NEW' }
              ]
            )
          end

          it 'returns validation error for duplicate name' do
            errors = subject.validate_form_526_fes_values
            expect(errors).to be_an(Array)
            error = errors.find { |e| e[:detail].include?('Duplicate disability name found: PTSD') }
            expect(error).not_to be_nil
            expect(error[:source]).to eq('/disabilities')
          end
        end

        context 'when all disability names are unique' do
          let(:form_attributes) do
            base_form_attributes.merge(
              'disabilities' => [
                { 'name' => 'PTSD', 'disabilityActionType' => 'NEW' },
                { 'name' => 'Back Pain', 'disabilityActionType' => 'NEW' },
                { 'name' => 'Knee Pain', 'disabilityActionType' => 'NEW' }
              ]
            )
          end

          it 'returns no duplicate name errors' do
            errors = subject.validate_form_526_fes_values
            # Should have no errors for unique names
            expect(errors).to be_nil
          end
        end
      end
    end

    # FES Val Section 10: Special Circumstances
    context 'special circumstances validation' do
      context 'when special circumstances exceed 100' do
        let(:form_attributes) do
          circumstances = Array.new(101) { |i| "Circumstance #{i}" }
          base_form_attributes.merge('specialCircumstances' => circumstances)
        end

        it 'returns validation error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_an(Array)
          error = errors.find { |e| e[:detail] == 'A maximum of 100 special circumstances are allowed' }
          expect(error).not_to be_nil
          expect(error[:source]).to eq('/specialCircumstances')
        end
      end

      context 'when special circumstances are within limit' do
        let(:form_attributes) do
          circumstances = Array.new(100) { |i| "Circumstance #{i}" }
          base_form_attributes.merge('specialCircumstances' => circumstances)
        end

        it 'returns no error' do
          errors = subject.validate_form_526_fes_values
          expect(errors).to be_nil
        end
      end
    end
  end
end
