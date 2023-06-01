# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'push register', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'PUT /mobile/v0/push/register' do
    context 'with a valid put body' do
      it 'matches the register schema' do
        params = {
          appName: 'va_mobile_app',
          deviceToken: '09d5a13a03b64b669f5ac0c32a0db6ad',
          osName: 'ios',
          osVersion: '13.1',
          deviceName: 'My Iphone',
          debug: 'false'
        }
        VCR.use_cassette('vetext/register_success') do
          put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('push_register')
        end
      end

      it 'with no device name matches the register schema' do
        params = {
          appName: 'va_mobile_app',
          deviceToken: '09d5a13a03b64b669f5ac0c32a0db6ad',
          osName: 'ios',
          osVersion: '13.1',
          debug: 'false'
        }
        VCR.use_cassette('vetext/register_success') do
          put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('push_register')
        end
      end
    end

    context 'with a valid put body and debug flag' do
      it 'matches the register schema' do
        params = {
          appName: 'va_mobile_app',
          deviceToken: '09d5a13a03b64b669f5ac0c32a0db6ad',
          osName: 'ios',
          osVersion: '13.1',
          deviceName: 'My Iphone',
          debug: 'true'
        }
        VCR.use_cassette('vetext/register_success') do
          put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('push_register')
        end
      end
    end

    context 'with invalid appName' do
      it 'matches the errors schema and responds not found' do
        params = {
          appName: 'bad_name',
          deviceToken: '09d5a13a03b64b669f5ac0c32a0db6ad',
          osName: 'ios',
          osVersion: '13.1',
          deviceName: 'My Iphone',
          debug: 'false'
        }
        put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'with bad request' do
      it 'returns bad request and errors' do
        params = {
          appName: 'va_mobile_app',
          deviceToken: '9bad7c63574f75f46944c6436a01b7c41c0776d6f061aa46b0884cdd93bb6959',
          osName: 'ios',
          osVersion: '13.1',
          deviceName: 'My Iphone',
          debug: 'false'
        }
        VCR.use_cassette('vetext/register_bad_request') do
          put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
      it 'returns bad gateway and errors' do
        params = {
          appName: 'va_mobile_app',
          deviceToken: '9bad7c63574f75f46944c6436a01b7c41c0776d6f061aa46b0884cdd93bb6959',
          osName: 'ios',
          osVersion: '13.1',
          deviceName: 'My Iphone',
          debug: 'false'
        }
        VCR.use_cassette('vetext/register_internal_server_error') do
          put '/mobile/v0/push/register', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
