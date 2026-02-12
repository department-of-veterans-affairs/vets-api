# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/submissions'
require 'digital_forms_api/service/schema'
require 'digital_forms_api/validation/submission_request'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::Submissions do
  let(:service) { described_class.new }

  let(:payload) do
    { data: 'TEST' }
  end
  let(:metadata) do
    {
      formId: '99t-12345',
      veteranId: '123456789v12345',
      claimantId: 'another-identifier',
      epCode: '99999999',
      claimLabel: '99999999DPEBNAJRE'
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

  let(:uuid) { SecureRandom.hex }

  it_behaves_like 'a DigitalFormsApi::Service class'

  describe 'submit' do
    it 'performs a POST' do
      schema_service = instance_double(DigitalFormsApi::Service::Schema)
      submission_validator = instance_double(DigitalFormsApi::Validation::SubmissionRequest)

      allow(DigitalFormsApi::Service::Schema).to receive(:new).and_return(schema_service)
      allow(DigitalFormsApi::Validation::SubmissionRequest).to receive(:new).and_return(submission_validator)

      schema = build(:digital_forms_api_schema)
      allow(schema_service).to receive(:fetch).with(metadata[:formId]).and_return(schema)

      expected = metadata.deep_dup
      expected[:claimantId] = { identifierType: 'PARTICIPANTID', value: expected[:claimantId] }
      expected[:veteranId] = { identifierType: 'PARTICIPANTID', value: expected[:veteranId] }

      expected = { envelope: expected.merge({ payload: }) }

      expect(submission_validator).to receive(:validate).with(payload:, metadata:,
                                                              form_schema: schema).and_return(expected)
      expect(service).to receive(:perform).with(:post, 'submissions?dry-run=false', expected, {})
      service.submit(payload, metadata)
    end

    it 'fetches schema with string-key metadata' do
      schema_service = instance_double(DigitalFormsApi::Service::Schema)
      submission_validator = instance_double(DigitalFormsApi::Validation::SubmissionRequest)

      allow(DigitalFormsApi::Service::Schema).to receive(:new).and_return(schema_service)
      allow(DigitalFormsApi::Validation::SubmissionRequest).to receive(:new).and_return(submission_validator)

      schema = build(:digital_forms_api_schema)
      allow(schema_service).to receive(:fetch).with('99t-12345').and_return(schema)

      expected = {
        envelope: {
          formId: '99t-12345',
          veteranId: { identifierType: 'PARTICIPANTID', value: '123456789v12345' },
          claimantId: { identifierType: 'PARTICIPANTID', value: 'another-identifier' },
          epCode: '99999999',
          claimLabel: '99999999DPEBNAJRE',
          payload:
        }
      }

      expect(submission_validator).to receive(:validate).with(payload:, metadata: string_key_metadata,
                                                              form_schema: schema).and_return(expected)
      expect(service).to receive(:perform).with(:post, 'submissions?dry-run=false', expected, {})

      service.submit(payload, string_key_metadata)
    end
  end

  describe 'retrieve' do
    it 'performs a GET' do
      expect(service).to receive(:perform).with(:get, "submissions/#{uuid}", {}, {})
      service.retrieve(uuid)
    end
  end
end
