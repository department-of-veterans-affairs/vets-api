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

      # Mock any methods the module might expect to be present
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
end
