# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/validation'

RSpec.describe DigitalFormsApi::Validation do
  let(:schema) { build(:digital_forms_api_schema) }
  let(:schema_with_required) { build(:digital_forms_api_schema, :with_required) }

  describe '.validate_against_schema' do
    it 'validates a payload against the schema successfully' do
      expect do
        subject.validate_against_schema(schema_with_required,
                                        { contentName: 'test.pdf', providerData: { key: 'value' } })
      end.not_to raise_error
    end

    it 'raises an error for invalid payload' do
      expect do
        subject.validate_against_schema(schema_with_required, { contentName: 'test.pdf' })
      end.to raise_error(JSON::Schema::ValidationError)
    end
  end
end
