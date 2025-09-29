# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::AltRevisedDisabilityCompensationValidation do
  subject { test_class.new(form_attributes) }

  let(:test_class) do
    Class.new do
      include ClaimsApi::V2::AltRevisedDisabilityCompensationValidation

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
    end
  end
end
