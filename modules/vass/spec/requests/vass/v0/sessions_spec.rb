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

    # Stub VASS settings
    stub_vass_settings

    # Mock Settings for VANotify
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
    # Stub the template_id method to return our test template ID
    template_id_stub = double('template_id', vass_otp_email: 'vass-otp-email-template-id')
    vanotify_api_key = 'name-11111111-1111-1111-1111-111111111111-22222222-2222-2222-2222-222222222222'
    allow(Settings.vanotify.services.va_gov).to receive_messages(
      api_key: vanotify_api_key,
      template_id: template_id_stub
    )
  end

  describe 'POST /vass/v0/request-otc' do
    let(:params) do
      {
        uuid:,
        last_name:,
        dob: date_of_birth
      }
    end

    context 'with valid parameters and successful VASS API response' do
      it 'creates session and sends OTC' do
        allow(StatsD).to receive(:increment).and_call_original

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.request_otc.success',
          hash_including(tags: array_including('service:vass', 'endpoint:request_otc'))
        ).and_call_original

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

      it 'tracks success metrics' do
        allow(StatsD).to receive(:increment).and_call_original

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.request_otc.success',
          hash_including(tags: array_including('service:vass', 'endpoint:request_otc'))
        ).and_call_original

        VCR.use_cassette('vass/sessions/oauth_token', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/sessions/get_veteran_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/sessions/vanotify_send_otp', match_requests_on: %i[method uri]) do
              post '/vass/v0/request-otc', params:, as: :json
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
              stored_otp = redis_client.otc_data(uuid:)&.dig(:code)
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
              uuid:,
              last_name: invalid_last_name,
              dob: date_of_birth
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
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"action":"rate_limit_exceeded"', "\"vass_uuid\":\"#{uuid}"))
          .and_call_original

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
        uuid:,
        last_name:,
        dob: date_of_birth,
        otc: otp_code
      }
    end

    context 'with valid OTC' do
      before do
        # Store OTC and veteran metadata from create flow
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: otp_code, last_name:, dob: date_of_birth)
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
      end

      it 'validates OTC and returns JWT token' do
        allow(StatsD).to receive(:increment).and_call_original

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.success',
          hash_including(tags: array_including('service:vass', 'endpoint:authenticate_otc'))
        ).and_call_original

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['token']).to be_present
        expect(json_response['data']['tokenType']).to eq('Bearer')
        expect(json_response['data']['expiresIn']).to eq(7200)
      end

      it 'tracks success metrics' do
        allow(StatsD).to receive(:increment).and_call_original

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.success',
          hash_including(tags: array_including('service:vass', 'endpoint:authenticate_otc'))
        ).and_call_original

        post '/vass/v0/authenticate-otc', params:, as: :json
      end

      it 'deletes OTC after validation' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        redis_client = Vass::RedisClient.build
        stored_otc = redis_client.otc_data(uuid:)&.dig(:code)
        expect(stored_otc).to be_nil
      end

      it 'creates authenticated session keyed by uuid with jti' do
        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        jwt_token = json_response['data']['token']

        # Decode JWT to extract jti
        decoded_payload = JWT.decode(jwt_token, Settings.vass.jwt_secret, true, algorithm: 'HS256')[0]
        token_jti = decoded_payload['jti']

        redis_client = Vass::RedisClient.build
        session_data = redis_client.session(uuid:)
        expect(session_data).to be_present
        expect(session_data[:jti]).to eq(token_jti)
        expect(session_data[:edipi]).to eq(edipi)
        expect(session_data[:veteran_id]).to eq(uuid)
      end

      it 'logs jwt_issued event with jti for audit trail' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(
          a_string_including('"service":"vass"', '"action":"jwt_issued"', "\"vass_uuid\":\"#{uuid}\"", '"jti":')
        ).and_call_original

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid OTC' do
      before do
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: '000000', last_name:, dob: date_of_birth)
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
      end

      it 'returns unauthorized status' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn).with(
          a_string_including('"service":"vass"', '"action":"invalid_otc"', %("vass_uuid":"#{uuid}"))
        ).and_call_original

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
        stored_otc = redis_client.otc_data(uuid:)&.dig(:code)
        expect(stored_otc).to eq('000000')
      end
    end

    context 'with missing OTC' do
      it 'returns bad request status' do
        missing_otc_params = { uuid:, last_name:, dob: date_of_birth }
        post '/vass/v0/authenticate-otc', params: missing_otc_params, as: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['code']).to eq('missing_parameter')
        expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
      end
    end

    context 'with expired OTC' do
      it 'returns unauthorized status' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn).with(a_string_including('"service":"vass"', '"action":"otc_expired"',
                                                                       %("vass_uuid":"#{uuid}"))).and_call_original

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('otc_expired')
      end
    end

    context 'when validation rate limit is exceeded' do
      before do
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: otp_code, last_name:, dob: date_of_birth)
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
        # Exceed validation rate limit
        5.times { redis_client.increment_validation_rate_limit(identifier: uuid) }
      end

      it 'returns too many requests status with account_locked code' do
        allow(Rails.logger).to receive(:warn).and_call_original
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"action":"validation_rate_limit_exceeded"'))
          .and_call_original

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('account_locked')
        expect(json_response['errors'][0]['detail']).to eq('Too many failed attempts. Please request a new OTC.')
        expect(json_response['errors'][0]['retryAfter']).to be_a(Integer)
      end
    end

    context 'when an exception occurs during successful authentication flow' do
      before do
        redis_client = Vass::RedisClient.build
        redis_client.save_otc(uuid:, code: otp_code, last_name:, dob: date_of_birth)
        redis_client.save_veteran_metadata(uuid:, edipi:, veteran_id: uuid)
      end

      it 'returns 503 when Redis fails during reset_validation_rate_limit' do
        allow(Rails.cache).to receive(:delete).and_raise(Redis::BaseError, 'Connection refused')

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['code']).to eq('service_unavailable')
      end

      it 'returns 503 when Redis fails during session creation' do
        allow(Rails.cache).to receive(:write).and_raise(Redis::BaseError, 'Connection refused')

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['code']).to eq('service_unavailable')
      end

      it 'returns error response body when Redis exception occurs' do
        allow(Rails.cache).to receive(:delete).and_raise(Redis::BaseError, 'Connection refused')

        post '/vass/v0/authenticate-otc', params:, as: :json

        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('errors')
        expect(json_response).not_to have_key('data')
      end

      it 'returns 500 with audit_log_error code when log_vass_event raises JSON::GeneratorError' do
        call_count = 0
        allow(Rails.logger).to receive(:info) do
          call_count += 1
          raise JSON::GeneratorError, 'Invalid encoding' if call_count == 1
        end

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['code']).to eq('audit_log_error')
      end

      it 'returns 500 with audit_log_error code when log_vass_event raises Encoding::UndefinedConversionError' do
        call_count = 0
        allow(Rails.logger).to receive(:info) do
          call_count += 1
          raise Encoding::UndefinedConversionError, 'Invalid byte sequence' if call_count == 1
        end

        post '/vass/v0/authenticate-otc', params:, as: :json

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['code']).to eq('audit_log_error')
      end

      it 'tracks failure and NOT success when Redis fails during handle_successful_authentication' do
        allow(Rails.cache).to receive(:delete).and_raise(Redis::BaseError, 'Connection refused')

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.failure',
          hash_including(tags: array_including('service:vass', 'endpoint:authenticate_otc'))
        )
        expect(StatsD).not_to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.success',
          anything
        )

        post '/vass/v0/authenticate-otc', params:, as: :json
      end

      it 'tracks failure and NOT success when audit log fails' do
        call_count = 0
        allow(Rails.logger).to receive(:info) do
          call_count += 1
          raise JSON::GeneratorError, 'Invalid encoding' if call_count == 1
        end

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.failure',
          hash_including(tags: array_including('service:vass', 'endpoint:authenticate_otc'))
        )
        expect(StatsD).not_to receive(:increment).with(
          'api.vass.controller.sessions.authenticate_otc.success',
          anything
        )

        post '/vass/v0/authenticate-otc', params:, as: :json
      end
    end
  end
end
