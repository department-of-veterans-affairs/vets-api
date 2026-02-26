# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../../../app/services/facilities_api/v2/lighthouse/middleware/errors'

RSpec.describe FacilitiesApi::V2::Lighthouse::Middleware::Errors do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { Faraday::Response.new(env) } }

  def process(body:, status:, content_type: 'application/json')
    env = Faraday::Env.from(
      status:,
      body:,
      response_headers: { 'Content-Type' => content_type }
    )
    middleware.on_complete(env)
    env
  end

  describe '#on_complete' do
    context 'when response is successful' do
      it 'does not modify the body' do
        original_body = '{"data": "test"}'
        env = process(body: original_body, status: 200)
        expect(env.body).to eq(original_body)
      end
    end

    context 'when response is an error with valid JSON' do
      it 'parses the body and adds detail, code, and source fields' do
        error_body = '{"message": "Invalid authentication credentials"}'
        env = process(body: error_body, status: 401)

        expect(env.body).to be_a(Hash)
        expect(env.body['message']).to eq('Invalid authentication credentials')
        expect(env.body['detail']).to eq('Invalid authentication credentials')
        expect(env.body['code']).to eq(401)
        expect(env.body['source']).to eq('Lighthouse Facilities')
      end
    end

    context 'when response is an error with HTML instead of JSON' do
      let(:html_error_body) { '<html><body><h1>503 Service Unavailable</h1></body></html>' }

      it 'handles the non-JSON response gracefully' do
        env = process(body: html_error_body, status: 503)

        expect(env.body).to be_a(Hash)
        expect(env.body['detail']).to eq('Unexpected response from Lighthouse Facilities')
        expect(env.body['code']).to eq(503)
        expect(env.body['source']).to eq('Lighthouse Facilities')
      end
    end

    context 'when response is an error with empty body' do
      it 'handles the empty body gracefully' do
        env = process(body: '', status: 500)

        expect(env.body).to be_a(Hash)
        expect(env.body['detail']).to eq('Unexpected response from Lighthouse Facilities')
        expect(env.body['code']).to eq(500)
        expect(env.body['source']).to eq('Lighthouse Facilities')
      end
    end
  end
end
