# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::V0::SessionsController, type: :controller do
  routes { Vass::Engine.routes }

  let(:redis_client) { instance_double(Vass::RedisClient) }
  let(:session_model) { instance_double(Vass::V0::Session) }
  let(:valid_email) { 'veteran@example.com' }
  let(:valid_phone) { '5555551234' }
  let(:uuid) { SecureRandom.uuid }
  let(:otp_code) { '123456' }
  let(:session_token) { SecureRandom.uuid }

  before do
    allow(Vass::RedisClient).to receive(:build).and_return(redis_client)
    allow(StatsD).to receive(:increment)
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
        allow(session_model).to receive(:valid_for_creation?).and_return(true)
        allow(session_model).to receive(:contact_value).and_return(valid_email)
        allow(session_model).to receive(:uuid).and_return(uuid)
        allow(session_model).to receive(:contact_method).and_return('email')
        allow(session_model).to receive(:generate_otp).and_return(otp_code)
        allow(session_model).to receive(:save_otp)
        allow(session_model).to receive(:creation_response).and_return({
                                                                          uuid:,
                                                                          message: 'OTP generated successfully'
                                                                        })
        allow(redis_client).to receive(:rate_limit_exceeded?).and_return(false)
        allow(redis_client).to receive(:increment_rate_limit)
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
        allow(session_model).to receive(:valid_for_creation?).and_return(false)
        allow(session_model).to receive(:validation_error_response).and_return({
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
        allow(session_model).to receive(:valid_for_creation?).and_return(true)
        allow(session_model).to receive(:contact_value).and_return(valid_email)
        allow(redis_client).to receive(:rate_limit_exceeded?).and_return(true)
      end

      it 'raises RateLimitError' do
        expect do
          post :create, params:, format: :json
        end.to raise_error(Vass::Errors::RateLimitError)
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
        allow(session_model).to receive(:valid_for_validation?).and_return(true)
        allow(session_model).to receive(:valid_otp?).and_return(true)
        allow(session_model).to receive(:delete_otp)
        allow(session_model).to receive(:generate_session_token).and_return(session_token)
        allow(session_model).to receive(:uuid).and_return(uuid)
        allow(session_model).to receive(:validation_response).and_return({
                                                                            session_token:,
                                                                            message: 'OTP validated successfully'
                                                                          })
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
        allow(session_model).to receive(:valid_for_validation?).and_return(true)
        allow(session_model).to receive(:valid_otp?).and_return(false)
        allow(session_model).to receive(:uuid).and_return(uuid)
        allow(session_model).to receive(:invalid_otp_response).and_return({
                                                                             error: true,
                                                                             message: 'Invalid OTP code'
                                                                           })
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
        allow(session_model).to receive(:valid_for_validation?).and_return(false)
        allow(session_model).to receive(:validation_error_response).and_return({
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

