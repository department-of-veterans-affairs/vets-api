# frozen_string_literal: true

require 'rails_helper'
require 'fes_service/base'

describe ClaimsApi::FesService::Base do
  let(:service) { described_class.new }
  let(:claim) do
    double('claim',
           id: 123,
           transaction_id: 'abc-123-def',
           auth_headers: { 'va_eauth_pid' => '600043201' },
           veteran: double('veteran', participant_id: '600043201'),
           claimant_participant_id: nil)
  end
  let(:form_data) do
    {
      form526: {
        'veteran' => { 'firstName' => 'John', 'lastName' => 'Doe' },
        'disabilities' => [{ 'name' => 'Hearing Loss' }]
      }
    }
  end

  # NOTE: FES service uses betamocks when use_mocks is true (set in test.yml)
  # This simplifies testing by eliminating the need for auth token mocking

  describe '#initialize' do
    it 'defaults to using mocks in test environment' do
      service = described_class.new
      expect(service.instance_variable_get(:@use_mock)).to be true
    end

    it 'allows override of mock setting' do
      service_with_mocks = described_class.new(nil, use_mock: true)
      expect(service_with_mocks.instance_variable_get(:@use_mock)).to be true

      service_without_mocks = described_class.new(nil, use_mock: false)
      expect(service_without_mocks.instance_variable_get(:@use_mock)).to be false
    end
  end

  describe '#validate' do
    context 'successful validation' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/validate')
          .with(body: form_data.to_json)
          .to_return(
            status: 200,
            body: { data: { valid: true, claimId: '600236153' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns validation success' do
        response = service.validate(claim, form_data)

        expect(response).to eq({ valid: true, claimId: '600236153' })
      end
    end

    context 'validation with errors' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/validate')
          .to_return(
            status: 200,
            body: {
              data: {
                valid: false,
                errors: [{ key: 'veteran.phoneAndEmail', detail: 'Required field' }]
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns validation errors' do
        response = service.validate(claim, form_data)

        expect(response[:valid]).to be(false)
        expect(response[:errors]).to be_present
      end
    end

    context 'service error' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/validate')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises backend service exception' do
        expect { service.validate(claim, form_data) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException)
      end
    end

    context 'non-JSON response' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/validate')
          .to_return(
            status: 200,
            body: '<html>Error page</html>',
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'raises parsing error' do
        expect { service.validate(claim, form_data) }
          .to raise_error(Common::Client::Errors::ParsingError,
                          'FES service returned an unexpected response format')
      end
    end
  end

  describe '#submit' do
    context 'successful submission' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/submit')
          .with(body: form_data.to_json)
          .to_return(
            status: 200,
            body: {
              data: {
                claimId: '600236153',
                submissionDate: '2025-01-15T12:34:56Z',
                status: 'ACCEPTED'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns submission success' do
        response = service.submit(claim, form_data)

        expect(response[:claimId]).to eq('600236153')
        expect(response[:status]).to eq('ACCEPTED')
        expect(response[:submissionDate]).to be_present
      end
    end

    context 'submission error' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/submit')
          .to_return(
            status: 400,
            body: {
              errors: [{
                status: 400,
                title: 'Invalid field value',
                detail: 'Invalid disability code'
              }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises backend service exception' do
        expect { service.submit(claim, form_data) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException)
      end
    end

    context 'non-JSON response' do
      before do
        stub_request(:post, 'https://staging-api.va.gov/form526-establishment-service/v1/submit')
          .to_return(
            status: 200,
            body: '<html><body><h1>503 Service Unavailable</h1>' \
                  '<p>The server is temporarily unable to service your request.</p></body></html>',
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'raises parsing error' do
        expect { service.submit(claim, form_data) }
          .to raise_error(Common::Client::Errors::ParsingError,
                          'FES service returned an unexpected response format')
      end
    end
  end
end
