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
  end

  describe 'submit_with_context' do
    it 'returns a portable context with submission UUID and veteran association' do
      response = build(:digital_forms_service_response, :success)
      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(response)

      expect(service.submit_with_context(payload, metadata)).to eq(
        {
          submission_uuid: 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
          form_id: '99t-12345',
          veteran_participant_id: '123456789v12345',
          claimant_participant_id: 'another-identifier'
        }
      )
    end

    it 'falls back claimant participant id to veteran participant id when claimantId is not provided' do
      response = build(:digital_forms_service_response, :success)
      metadata_without_claimant = metadata.except(:claimantId)
      expect(service).to receive(:submit).with(payload, metadata_without_claimant, dry_run: false).and_return(response)

      expect(service.submit_with_context(payload, metadata_without_claimant)).to eq(
        {
          submission_uuid: 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
          form_id: '99t-12345',
          veteran_participant_id: '123456789v12345',
          claimant_participant_id: '123456789v12345'
        }
      )
    end

    it 'returns nil submission_uuid when Digital Forms response does not include one' do
      response = build(:digital_forms_service_response, :success)
      response.body = { submission: { claimId: '123456789' } }
      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(response)

      expect(service.submit_with_context(payload, metadata)).to eq(
        {
          submission_uuid: nil,
          form_id: '99t-12345',
          veteran_participant_id: '123456789v12345',
          claimant_participant_id: 'another-identifier'
        }
      )
    end
  end

  describe 'retrieve' do
    it 'performs a GET' do
      expect(service).to receive(:perform).with(:get, "submissions/#{uuid}", {}, {})
      service.retrieve(uuid)
    end
  end
end
