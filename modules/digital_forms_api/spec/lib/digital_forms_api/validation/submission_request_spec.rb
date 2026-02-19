# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/validation/submission_request'
require 'digital_forms_api/validation/schema'

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

  describe '#validate' do
    context 'when endpoint schema is a request schema' do
      let(:request_schema) do
        {
          'type' => 'object',
          'required' => ['envelope'],
          'properties' => {
            'envelope' => { 'type' => 'object' }
          }
        }
      end

      it 'validates the full request against the fetched schema' do
        expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(request_schema, request)

        expect(validator.validate(payload:, metadata:, form_schema: request_schema)).to eq(request)
      end
    end

    context 'when endpoint schema is a payload schema' do
      let(:payload_schema) { build(:digital_forms_api_schema, :with_required) }

      it 'validates payload against the fetched schema' do
        expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with(payload_schema, payload)

        expect(validator.validate(payload:, metadata:, form_schema: payload_schema)).to eq(request)
      end
    end
  end
end
