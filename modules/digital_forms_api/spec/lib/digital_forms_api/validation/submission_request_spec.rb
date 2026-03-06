# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/validation/submission_request'
require 'digital_forms_api/validation'

RSpec.describe DigitalFormsApi::Validation::SubmissionRequest do
  let(:validator) { described_class.new }
  let(:payload) { { data: 'TEST' } }
  let(:metadata) do
    {
      formId: '99t-12345',
      veteranId: '123456789v12345',
      claimantId: 'another-identifier',
      epCode: '99999999',
      claimLabel: '99999999DPEBNAJRE'
    }
  end
  let(:request) do
    {
      envelope: {
        formId: '99t-12345',
        veteranId: { identifierType: 'PARTICIPANTID', value: '123456789v12345' },
        claimantId: { identifierType: 'PARTICIPANTID', value: 'another-identifier' },
        epCode: '99999999',
        claimLabel: '99999999DPEBNAJRE',
        payload: { data: 'TEST' }
      }
    }
  end
  let(:string_key_metadata) do
    {
      'formId' => '99t-12345',
      'veteranId' => '123456789v12345',
      'claimantId' => 'another-identifier',
      'epCode' => '99999999',
      'claimLabel' => '99999999DPEBNAJRE'
    }
  end
  let(:form_schema) { build(:digital_forms_api_schema, :with_required) }
  let(:request_schema) { build(:digital_forms_api_request_schema) }

  describe '#validate' do
    it 'validates the payload against the form schema and returns the request envelope' do
      expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(form_schema, payload).ordered
      expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(request_schema, request).ordered

      expect(validator.validate(payload:, metadata:, form_schema:, request_schema:)).to eq(request)
    end

    it 'normalizes string-key metadata and returns a valid request envelope' do
      expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(form_schema, payload).ordered
      expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(request_schema, request).ordered

      expect(validator.validate(payload:, metadata: string_key_metadata, form_schema:, request_schema:)).to eq(request)
    end

    context 'when metadata has both string and symbol keys for the same field' do
      let(:mixed_metadata) do
        {
          formId: '99t-12345',
          'formId' => 'should-be-ignored',
          veteranId: '123456789v12345',
          claimantId: 'another-identifier',
          epCode: '99999999',
          claimLabel: '99999999DPEBNAJRE'
        }
      end

      it 'prefers the symbol-keyed value' do
        expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(form_schema, payload).ordered
        expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(request_schema, request).ordered

        result = validator.validate(payload:, metadata: mixed_metadata, form_schema:, request_schema:)
        expect(result[:envelope][:formId]).to eq('99t-12345')
      end
    end
  end
end
