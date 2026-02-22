# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/submissions'

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
      expected = metadata.deep_dup
      expected[:claimantId] = { identifierType: 'PARTICIPANTID', value: expected[:claimantId] }
      expected[:veteranId] = { identifierType: 'PARTICIPANTID', value: expected[:veteranId] }

      expected = { envelope: expected.merge({ payload: }) }

      expect(service).to receive(:perform).with(:post, 'submissions?dry-run=false', expected, {})
      service.submit(payload, metadata)
    end
  end

  describe 'submit_with_uuid' do
    it 'returns synchronous true and uuid when successful response contains submissionId' do
      response = build(:digital_forms_service_response, :success)
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:response]).to be(response)
      expect(result[:submission_uuid]).to be(response.body.dig('submission', 'submissionId'))
      expect(result[:synchronous]).to be(true)
    end

    it 'returns synchronous false when uuid is missing from response body' do
      response = build(:digital_forms_service_response, :success)
      response.body = { submission: { claimId: '123456789' } }
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be_nil
      expect(result[:synchronous]).to be(false)
    end

    it 'reads uuid from symbolized submission shape' do
      response = instance_double(Faraday::Response, body: { submission: { submissionId: 'abc-123' } }, success?: true)
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be('abc-123')
      expect(result[:synchronous]).to be(true)
    end

    it 'returns synchronous false for unsuccessful 4xx response even when uuid is present' do
      response = instance_double(
        Faraday::Response,
        body: { 'submission' => { 'submissionId' => 'abc-uuid' } },
        success?: false,
        status: 422
      )
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be('abc-uuid')
      expect(result[:synchronous]).to be(false)
    end

    it 'returns synchronous false when response does not expose success? and has 5xx status' do
      response = instance_double(
        Faraday::Response,
        body: { 'submission' => { 'submissionId' => 'abc-uuid' } },
        status: 503
      )
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be('abc-uuid')
      expect(result[:synchronous]).to be(false)
    end

    it 'handles nil response safely' do
      allow(service).to receive(:submit).and_return(nil)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:response]).to be_nil
      expect(result[:submission_uuid]).to be_nil
      expect(result[:synchronous]).to be(false)
    end

    it 'handles string response body safely' do
      response = instance_double(Faraday::Response, body: 'not-json', success?: true)
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be_nil
      expect(result[:synchronous]).to be(false)
    end

    it 'handles array response body safely' do
      response = instance_double(
        Faraday::Response,
        body: [{ submission: { submissionId: 'abc-uuid' } }],
        success?: true
      )
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be_nil
      expect(result[:synchronous]).to be(false)
    end

    it 'treats blank submission id as missing' do
      response = instance_double(Faraday::Response, body: { 'submission' => { 'submissionId' => '' } }, success?: true)
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be_nil
      expect(result[:synchronous]).to be(false)
    end

    it 'reads uuid from string-keyed response body' do
      response = instance_double(
        Faraday::Response,
        body: { 'submission' => { 'submissionId' => 'string-key-uuid' } },
        success?: true
      )
      allow(service).to receive(:submit).and_return(response)

      result = service.submit_with_uuid(payload, metadata)

      expect(result[:submission_uuid]).to be('string-key-uuid')
      expect(result[:synchronous]).to be(true)
    end
  end

  describe 'retrieve' do
    it 'performs a GET' do
      expect(service).to receive(:perform).with(:get, "submissions/#{uuid}", {}, {})
      service.retrieve(uuid)
    end
  end
end
