# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'push register', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  describe 'PUT /mobile/v0/push/register' do
    context 'with a valid put body' do
      it 'matches the register schema' do
        params = {
            appName: 'va_mobile_app',
            deviceToken: '09d5a13a03b64b669f5ac0c32a0db6ad',
            osName: 'ios',
            osVersion: '13.1',
            deviceName: "My Iphone"
        }
        VCR.use_cassette('vetext/register_success') do
          put '/mobile/v0/push/register', headers: iam_headers, params: params
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
            deviceName: "My Iphone"
        }
        put '/mobile/v0/push/register', headers: iam_headers, params: params
        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('errors')
      end
    end
  end
end
