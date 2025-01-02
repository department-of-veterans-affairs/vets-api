# frozen_string_literal: true

require 'rails_helper'
require 'faraday'
require 'json'

RSpec.describe AccreditationService do
  let(:parsed_body) { { field: 'value' } }
  let(:user_uuid) { 'test-user-uuid' }

  describe '#submit_form21a' do
    context 'when the request is successful' do
      it 'returns a successful response' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_return(status: 200, body: parsed_body.to_json, headers: { 'Content-Type' => 'application/json' })

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(200)
        expect(response.body).to eq(parsed_body.stringify_keys)
      end
    end

    context 'when the connection fails' do
      it 'logs the error and returns a service unavailable status' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_raise(Faraday::ConnectionFailed.new('Accreditation Service connection failed'))

        expect(Rails.logger).to receive(:error).with(
          "Accreditation Service connection failed for user with user_uuid=#{user_uuid}: " \
          "Accreditation Service connection failed, URL: #{Settings.ogc.form21a_service_url.url}"
        )

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(:service_unavailable)
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service unavailable')
      end
    end

    context 'when the request times out' do
      it 'logs the error and returns a request timeout status' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_raise(Faraday::TimeoutError.new('Request timed out'))

        expect(Rails.logger).to receive(:error).with(
          "Accreditation Service request timed out for user with user_uuid=#{user_uuid}: Request timed out"
        )

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(:request_timeout)
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service request timed out')
      end
    end
  end
end
