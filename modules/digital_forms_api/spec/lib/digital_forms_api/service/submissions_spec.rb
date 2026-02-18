# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/submissions'
require 'digital_forms_api/service/schema'
require 'digital_forms_api/validation/schema'

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
      allow(DigitalFormsApi::Service::Schema).to receive(:new).and_return(schema_service)
      allow(schema_service).to receive(:fetch).with(metadata[:formId]).and_return({})
      allow(DigitalFormsApi::Validation).to receive(:validate_against_schema)

      expected = metadata.deep_dup
      expected[:claimantId] = { identifierType: 'PARTICIPANTID', value: expected[:claimantId] }
      expected[:veteranId] = { identifierType: 'PARTICIPANTID', value: expected[:veteranId] }

      expected = { envelope: expected.merge({ payload: }) }

      expect(DigitalFormsApi::Validation).to receive(:validate_against_schema).with({}, payload)
      expect(service).to receive(:perform).with(:post, 'submissions?dry-run=false', expected, {})
      service.submit(payload, metadata)
    end
  end

  describe 'retrieve' do
    it 'performs a GET' do
      expect(service).to receive(:perform).with(:get, "submissions/#{uuid}", {}, {})
      service.retrieve(uuid)
    end
  end
end
