# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/services/vass/va_notify_service'

RSpec.describe 'Vass::V0::Sessions', type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:uuid) { 'da1e1a40-1e63-f011-bec2-001dd80351ea' }
  let(:last_name) { 'Smith' }
  let(:date_of_birth) { '1990-01-15' }
  let(:valid_email) { 'veteran@example.com' }
  let(:edipi) { '1234567890' }
  let(:otp_code) { '123456' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Stub VASS settings (same pattern as service specs)
    allow(Settings).to receive(:vass).and_return(
      OpenStruct.new(
        auth_url: 'https://login.microsoftonline.us',
        tenant_id: 'test-tenant-id',
        client_id: 'test-client-id',
        client_secret: 'test-client-secret',
        scope: 'https://api.va.gov/.default',
        api_url: 'https://api.vass.va.gov',
        subscription_key: 'test-subscription-key',
        service_name: 'vass_api',
        redis_otc_expiry: 600,
        redis_session_expiry: 7200,
        redis_token_expiry: 3540,
        rate_limit_max_attempts: 5,
        rate_limit_expiry: 900
      )
    )

    # Mock Settings for VANotify
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
    # Stub the template_id method to return our test template ID
    template_id_stub = double('template_id', vass_otp_email: 'vass-otp-email-template-id')
    vanotify_api_key = '11111111-1111-1111-1111-111111111111-22222222-2222-2222-2222-222222222222'
    allow(Settings.vanotify.services.va_gov).to receive_messages(
      api_key: vanotify_api_key,
      template_id: template_id_stub
    )
  end

  describe 'POST /vass/v0/request-otc' do
    let(:params) do
      {
        session: {
          uuid:,
          last_name:,
          dob: date_of_birth
        }
      }
    end

    context 'with valid parameters and successful VASS API response' do
      it 'creates session and sends OTC' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/sessions/vanotify_send_otp', match_requests_on: %i[method uri]) do
              post '/vass/v0/request-otc', params:, as: :json

              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)
              expect(json_response['data']['message']).to eq('OTC sent to registered email address')
              expect(json_response['data']['expiresIn']).to be_a(Integer)
            end
          end
        end
      end

      it 'validates identity against VASS response' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/sessions/vanotify_send_otp', match_requests_on: %i[method uri]) do
              post '/vass/v0/request-otc', params:, as: :json

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      it 'stores OTP in Redis' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/sessions/vanotify_send_otp', match_requests_on: %i[method uri]) do
              post '/vass/v0/request-otc', params:, as: :json

              expect(response).to have_http_status(:ok)
              # OTP should be stored in Redis
              redis_client = Vass::RedisClient.build
              stored_otp = redis_client.otc(uuid:)
              expect(stored_otp).to be_present
              expect(stored_otp.length).to eq(6)
            end
          end
        end
      end

      it 'stores veteran metadata in Redis' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/sessions/vanotify_send_otp', match_requests_on: %i[method uri]) do
              post '/vass/v0/request-otc', params:, as: :json

              expect(response).to have_http_status(:ok)
              # Veteran metadata should be stored
              redis_client = Vass::RedisClient.build
              metadata = redis_client.veteran_metadata(uuid:)
              expect(metadata).to be_present
              expect(metadata[:edipi]).to eq(edipi)
              expect(metadata[:veteran_id]).to eq(uuid)
            end
          end
        end
      end
    end

    context 'when identity validation fails' do
      let(:invalid_last_name) { 'WrongName' }

      it 'returns unauthorized status' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            post '/vass/v0/request-otc', params: {
              session: {
                uuid:,
                last_name: invalid_last_name,
                dob: date_of_birth
              }
            }, as: :json

            expect(response).to have_http_status(:unauthorized)
            json_response = JSON.parse(response.body)
            expect(json_response['errors']).to be_present
            expect(json_response['errors'].first['code']).to eq('invalid_credentials')
          end
        end
      end
    end

    context 'when contact info is missing' do
      it 'returns unprocessable entity status' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_missing_contact', match_requests_on: %i[method uri]) do
            post '/vass/v0/request-otc', params:, as: :json

            expect(response).to have_http_status(:unprocessable_entity)
            json_response = JSON.parse(response.body)
            expect(json_response['errors']).to be_present
            expect(json_response['errors'].first['code']).to eq('missing_contact_info')
          end
        end
      end
    end

    context 'when rate limit is exceeded' do
      before do
        redis_client = Vass::RedisClient.build
        # Exceed rate limit
        5.times { redis_client.increment_rate_limit(identifier: uuid) }
      end

      it 'returns too many requests status' do
        # Rate limit check happens before any API calls, so no cassettes needed
        post '/vass/v0/request-otc', params:, as: :json

        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['retryAfter']).to be_a(Integer)
      end
    end

    context 'when VASS API returns error' do
      it 'returns bad gateway status' do
        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_api_error', match_requests_on: %i[method uri]) do
            post '/vass/v0/request-otc', params:, as: :json

            expect(response).to have_http_status(:bad_gateway)
            json_response = JSON.parse(response.body)
            expect(json_response['errors']).to be_present
          end
        end
      end
    end
  end

  describe 'POST /vass/v0/authenticate-otc' do
    let(:params) do
      {
        session: {
          uuid:,
          last_name:,
          dob: date_of_birth,
          otc: otp_code
        }
      }
    end

    context 'with valid OTC' do
      before do
        # Store OTC and veteran metadata from create flow
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: otp_code)
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
      end

      it 'validates OTC and returns JWT token' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['token']).to be_present
        expect(json_response['data']['tokenType']).to eq('Bearer')
        expect(json_response['data']['expiresIn']).to eq(3600)
      end

      it 'deletes OTC after validation' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        redis_client = Vass::RedisClient.build
        stored_otc = redis_client.otc(uuid:)
        expect(stored_otc).to be_nil
      end

      it 'creates authenticated session' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        jwt_token = json_response['data']['token']

        redis_client = Vass::RedisClient.build
        session_data = redis_client.session(session_token: jwt_token)
        expect(session_data).to be_present
        expect(session_data[:edipi]).to eq(edipi)
        expect(session_data[:veteran_id]).to eq(uuid)
        expect(session_data[:uuid]).to eq(uuid)
      end
    end

    context 'with invalid OTC' do
      before do
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: '000000')
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
      end

      it 'returns unauthorized status' do
        invalid_params = params.deep_merge(session: { otc: '999999' })
        post '/vass/v0/authenticate-otc', params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('invalid_otc')
        expect(json_response['errors'][0]['attemptsRemaining']).to be_a(Integer)
      end

      it 'does not delete OTC on failure' do
        invalid_params = params.deep_merge(session: { otc: '999999' })
        post '/vass/v0/authenticate-otc', params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        redis_client = Vass::RedisClient.build
        stored_otc = redis_client.otc(uuid:)
        expect(stored_otc).to eq('000000')
      end
    end

    context 'with missing OTC' do
      it 'returns unprocessable entity status' do
        missing_otc_params = { session: { uuid:, last_name:, dob: date_of_birth } }
        post '/vass/v0/authenticate-otc', params: missing_otc_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'with expired OTC' do
      it 'returns unauthorized status' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('otc_expired')
      end
    end
  end
end
