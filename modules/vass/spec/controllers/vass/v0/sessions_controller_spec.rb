# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/services/vass/vanotify_service'

RSpec.describe Vass::V0::SessionsController, type: :controller do
  routes { Vass::Engine.routes }

  let(:redis_client) { instance_double(Vass::RedisClient) }
  let(:session_model) { instance_double(Vass::V0::Session) }
  let(:vanotify_service) { instance_double(Vass::VANotifyService) }
  let(:valid_email) { 'veteran@example.com' }
  let(:valid_phone) { '5555551234' }
  let(:uuid) { SecureRandom.uuid }
  let(:otp_code) { '123456' }
  let(:session_token) { SecureRandom.uuid }

  before do
    allow(Vass::RedisClient).to receive(:build).and_return(redis_client)
    allow(Vass::VANotifyService).to receive(:build).and_return(vanotify_service)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe 'POST #create' do
    let(:params) do
      {
        session: {
          contact_method: 'email',
          contact_value: valid_email
        }
      }
    end

    context 'with valid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive(:save_otp)
        allow(session_model).to receive_messages(
          valid_for_creation?: true,
          contact_value: valid_email,
          uuid:,
          contact_method: 'email',
          generate_otp: otp_code,
          creation_response: {
            uuid:,
            message: 'OTP generated successfully'
          }
        )
        allow(redis_client).to receive(:rate_limit_exceeded?).and_return(false)
        allow(redis_client).to receive(:increment_rate_limit)
        allow(vanotify_service).to receive(:send_otp)
      end

      it 'returns success response' do
        post :create, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['uuid']).to eq(uuid)
        expect(json_response['message']).to eq('OTP generated successfully')
      end

      it 'generates and saves OTP' do
        expect(session_model).to receive(:generate_otp).and_return(otp_code)
        expect(session_model).to receive(:save_otp).with(otp_code)
        post :create, params:, format: :json
      end

      it 'increments rate limit counter' do
        expect(redis_client).to receive(:increment_rate_limit).with(identifier: valid_email)
        post :create, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otp_generated',
                                                   tags: ['service:vass'])
        post :create, params:, format: :json
      end
    end

    context 'with invalid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: false, validation_error_response: {
                                                   error: true,
                                                   message: 'Invalid session parameters'
                                                 })
      end

      it 'returns unprocessable entity status' do
        post :create, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be true
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :create, params:, format: :json
      end
    end

    context 'when rate limit exceeded' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: true, contact_value: valid_email)
        allow(redis_client).to receive(:rate_limit_exceeded?).and_return(true)
      end

      it 'returns too many requests status' do
        post :create, params:, format: :json
        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['title']).to eq('Rate Limit Exceeded')
      end

      it 'logs rate limit exceeded' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.rate_limit_exceeded',
                                                   tags: ['service:vass'])
        begin
          post :create, params:, format: :json
        rescue Vass::Errors::RateLimitError
          # Expected
        end
      end
    end

    context 'when VANotify fails' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_creation?: true,
          contact_value: valid_email,
          uuid:,
          contact_method: 'email',
          generate_otp: otp_code,
          save_otp: true,
          creation_response: {
            uuid:,
            message: 'OTP generated successfully'
          }
        )
        allow(redis_client).to receive(:rate_limit_exceeded?).and_return(false)
        allow(redis_client).to receive(:increment_rate_limit)
        allow(vanotify_service).to receive(:send_otp).and_raise(
          VANotify::Error.new(500, 'VANotify service unavailable')
        )
      end

      it 'returns bad gateway status' do
        post :create, params:, format: :json

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['title']).to eq('Notification Service Error')
      end

      it 'logs VANotify error' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            '"service":"vass"', '"action":"vanotify_error"', "\"uuid\":\"#{uuid}\"",
            '"error_class":"VANotify::Error"', '"status_code":500', '"contact_method":"email"'
          )
        )
        post :create, params:, format: :json
      end

      it 'increments StatsD metric for failed OTP send' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otp_send_failed',
                                                   tags: ['service:vass'])
        post :create, params:, format: :json
      end

      context 'with different VANotify error status codes' do
        it 'returns bad request for 400 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(400, 'Bad request'))
          post :create, params:, format: :json
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns too many requests for 429 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(429, 'Rate limit exceeded'))
          post :create, params:, format: :json
          expect(response).to have_http_status(:too_many_requests)
        end

        it 'returns service unavailable for unknown status codes' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(999, 'Unknown error'))
          post :create, params:, format: :json
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end
  end

  describe 'GET #show' do
    let(:params) do
      {
        id: uuid,
        otp_code:
      }
    end

    context 'with valid OTP' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive(:delete_otp)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          valid_otp?: true,
          generate_session_token: session_token,
          uuid:,
          validation_response: {
            session_token:,
            message: 'OTP validated successfully'
          }
        )
      end

      it 'returns success response with session token' do
        get :show, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['session_token']).to eq(session_token)
        expect(json_response['message']).to eq('OTP validated successfully')
      end

      it 'deletes the OTP after validation' do
        expect(session_model).to receive(:delete_otp)
        get :show, params:, format: :json
      end

      it 'generates a session token' do
        expect(session_model).to receive(:generate_session_token).and_return(session_token)
        get :show, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otp_validation_success',
                                                   tags: ['service:vass'])
        get :show, params:, format: :json
      end
    end

    context 'with invalid OTP' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          valid_otp?: false,
          uuid:,
          invalid_otp_response: {
            error: true,
            message: 'Invalid OTP code'
          }
        )
      end

      it 'returns unauthorized status' do
        get :show, params:, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be true
      end

      it 'does not delete the OTP' do
        expect(session_model).not_to receive(:delete_otp)
        get :show, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otp_validation_failed',
                                                   tags: ['service:vass'])
        get :show, params:, format: :json
      end
    end

    context 'with invalid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_validation?: false, validation_error_response: {
                                                   error: true,
                                                   message: 'Invalid session parameters'
                                                 })
      end

      it 'returns unprocessable entity status' do
        get :show, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be true
      end

      it 'does not validate OTP' do
        expect(session_model).not_to receive(:valid_otp?)
        get :show, params:, format: :json
      end
    end
  end

  describe 'private methods' do
    describe '#permitted_params' do
      it 'permits session attributes' do
        params = {
          session: {
            contact_method: 'email',
            contact_value: valid_email
          }
        }
        controller.params = ActionController::Parameters.new(params)
        permitted = controller.send(:permitted_params)
        expect(permitted).to be_permitted
        expect(permitted[:contact_method]).to eq('email')
        expect(permitted[:contact_value]).to eq(valid_email)
      end
    end
  end
end
