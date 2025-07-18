# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/validation/field'

RSpec.describe ClaimsEvidenceApi::Validation::BaseField do
  context 'via subclasses' do
    describe 'StringField' do
      it 'returns a valid value' do
        validations = {
          minimum: 2,
          maximum: 50,
          pattern: '[a-z]{2}(-\d{3}-\w+)?',
          enum: %w[a foo ab-123-testing bar]
        }

        field = ClaimsEvidenceApi::Validation::StringField.new(**validations)
        value = 'ab-123-testing'
        expect(value).to eq field.validate(value)
      end
    end

    describe 'IntegerField' do
      it 'returns a valid value' do
        validations = {
          minimum: 2,
          maximum: 50,
          enum: [1, 23, 42, 81]
        }

        field = ClaimsEvidenceApi::Validation::IntegerField.new(**validations)
        value = 23
        expect(value).to eq field.validate(value)
      end
    end

    describe 'NumberField' do
      it 'returns a valid value' do
        validations = {
          minimum: 1,
          maximum: 99
        }

        field = ClaimsEvidenceApi::Validation::NumberField.new(**validations)
        value = 45.689
        expect(value).to eq field.validate(value)
      end
    end

    describe 'BooleanField' do
      it 'returns a valid value' do
        field = ClaimsEvidenceApi::Validation::BooleanField.new
        value = 'any value should return true'
        expect(field.validate(value)).to be(true)

        expect(field.validate(nil)).to be(false)
      end
    end
  end
end
