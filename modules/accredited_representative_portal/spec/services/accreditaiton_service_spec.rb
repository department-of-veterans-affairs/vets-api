# frozen_string_literal: true

require 'rails_helper'
require 'faraday'
require 'json'

RSpec.describe AccreditationService do
  let(:parsed_body) { { field: 'value' } }

  describe '#submit_form21a' do
    context 'when the request is successful' do
      it 'returns a successful response' do
        stub_request(:post, 'http://localhost:5000/api/v1/accreditation/applications/form21a')
          .to_return(status: 200, body: parsed_body.to_json, headers: { 'Content-Type' => 'application/json' })

        response = described_class.submit_form21a(parsed_body)

        expect(response.status).to eq(200)
        expect(response.body).to eq(parsed_body.stringify_keys)
      end
    end

    context 'when the connection fails' do
      it 'returns a service unavailable status' do
        stub_request(:post, 'http://localhost:5000/api/v1/accreditation/applications/form21a')
          .to_raise(Faraday::ConnectionFailed.new('Accreditation Service connection failed'))

        response = described_class.submit_form21a(parsed_body)

        expect(response.status).to eq(:service_unavailable)
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service unavailable')
      end
    end

    context 'when the request times out' do
      it 'returns a request timeout status' do
        stub_request(:post, 'http://localhost:5000/api/v1/accreditation/applications/form21a')
          .to_raise(Faraday::TimeoutError.new('Request timed out'))

        response = described_class.submit_form21a(parsed_body)

        expect(response.status).to eq(:request_timeout)
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service request timed out')
      end
    end
  end
end
