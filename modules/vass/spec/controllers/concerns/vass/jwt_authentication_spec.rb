# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/vass_settings_helper'

RSpec.describe Vass::JwtAuthentication, type: :controller do
  controller(ActionController::Base) do
    include Vass::Logging
    include Vass::JwtAuthentication

    # Mirror the rescue_from handler in Vass::ApplicationController
    rescue_from Vass::Errors::AuthenticationError do |exception|
      render json: {
        errors: [{
          title: 'Authentication Error',
          detail: exception.message,
          code: 'unauthorized'
        }]
      }, status: :unauthorized
    end

    before_action :authenticate_jwt

    def index
      render json: { veteran_id: @current_veteran_id, jti: @current_jti }, status: :ok
    end
  end

  let(:veteran_id) { 'test-veteran-uuid-123' }
  let(:secret) { 'test-jwt-secret' }
  let(:redis_client) { instance_double(Vass::RedisClient) }

  before do
    stub_vass_settings(jwt_secret: secret)
    allow(Vass::RedisClient).to receive(:build).and_return(redis_client)
    allow(redis_client).to receive(:session_valid_for_jti?).and_return(true)
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe '#authenticate_jwt' do
    context 'with valid JWT token' do
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti: SecureRandom.uuid
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'authenticates successfully' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'sets @current_veteran_id' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['veteran_id']).to eq(veteran_id)
      end

      it 'makes current_veteran_id available as reader' do
        get :index
        expect(controller.current_veteran_id).to eq(veteran_id)
      end

      it 'sets @current_jti from token payload' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['jti']).to be_present
      end

      it 'makes current_jti available as reader' do
        get :index
        expect(controller.current_jti).to be_present
      end
    end

    context 'with missing Authorization header' do
      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders error message' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'][0]['code']).to eq('unauthorized')
        expect(json_response['errors'][0]['detail']).to eq('Missing authentication token')
      end

      it 'logs authentication failure' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"missing_token"'))
        get :index
      end
    end

    context 'with malformed Authorization header' do
      it 'returns 401 for header without Bearer prefix' do
        request.headers['Authorization'] = 'invalid-token-format'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 for empty Bearer token' do
        request.headers['Authorization'] = 'Bearer '
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'logs authentication failure for malformed header' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"missing_token"'))
        request.headers['Authorization'] = 'invalid-token-format'
        get :index
      end
    end

    context 'with expired JWT token' do
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.ago.to_i,
          iat: 2.hours.ago.to_i,
          jti: SecureRandom.uuid
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders token expired error' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors'][0]['detail']).to eq('Token has expired')
      end

      it 'logs authentication failure' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"expired_token"'))
        get :index
      end
    end

    context 'with invalid JWT signature' do
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti: SecureRandom.uuid
        }
      end
      let(:wrong_secret) { 'wrong-secret-key' }
      let(:token) { JWT.encode(payload, wrong_secret, 'HS256') }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders invalid token error' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors'][0]['detail']).to eq('Invalid or malformed token')
      end

      it 'logs authentication failure with error class' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"invalid_token"',
                                   '"error_class":"JWT::VerificationError"'))
        get :index
      end
    end

    context 'with missing veteran_id in token payload' do
      let(:payload) do
        {
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti: SecureRandom.uuid
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders missing veteran_id error' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors'][0]['detail']).to eq('Invalid or malformed token')
      end

      it 'logs authentication failure' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"missing_veteran_id"'))
        get :index
      end
    end

    context 'with completely invalid JWT format' do
      before do
        request.headers['Authorization'] = 'Bearer not-a-jwt-token'
      end

      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders decode error' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors'][0]['detail']).to eq('Invalid or malformed token')
      end

      it 'logs authentication failure with error class' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"invalid_token"',
                                   '"error_class":"JWT::DecodeError"'))
        get :index
      end
    end

    context 'with case-insensitive Bearer prefix' do
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti: SecureRandom.uuid
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      it 'accepts lowercase bearer' do
        request.headers['Authorization'] = "bearer #{token}"
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'accepts uppercase BEARER' do
        request.headers['Authorization'] = "BEARER #{token}"
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'accepts mixed case BeArEr' do
        request.headers['Authorization'] = "BeArEr #{token}"
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with revoked token (session deleted)' do
      let(:jti) { SecureRandom.uuid }
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti:
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      before do
        allow(redis_client).to receive(:session_valid_for_jti?).with(uuid: veteran_id, jti:).and_return(false)
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders revoked token error' do
        get :index
        json_response = JSON.parse(response.body)
        expect(json_response['errors'][0]['detail']).to eq('Token is invalid or already revoked')
      end

      it 'logs authentication failure' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_including('"service":"vass"', '"component":"jwt_authentication"',
                                   '"action":"auth_failure"', '"reason":"revoked_token"'))
        get :index
      end
    end
  end

  describe '#extract_token_from_header' do
    it 'extracts token from valid Bearer format' do
      request.headers['Authorization'] = 'Bearer test-token-123'
      token = controller.send(:extract_token_from_header)
      expect(token).to eq('test-token-123')
    end

    it 'returns nil when Authorization header is missing' do
      token = controller.send(:extract_token_from_header)
      expect(token).to be_nil
    end

    it 'returns nil for invalid format' do
      request.headers['Authorization'] = 'InvalidFormat test-token'
      token = controller.send(:extract_token_from_header)
      expect(token).to be_nil
    end
  end

  describe '#decode_jwt' do
    let(:payload) do
      {
        sub: veteran_id,
        exp: 1.hour.from_now.to_i,
        iat: Time.current.to_i
      }
    end
    let(:token) { JWT.encode(payload, secret, 'HS256') }

    it 'decodes valid token' do
      decoded = controller.send(:decode_jwt, token)
      expect(decoded['sub']).to eq(veteran_id)
    end

    it 'raises JWT::ExpiredSignature for expired token' do
      expired_payload = payload.merge(exp: 1.hour.ago.to_i)
      expired_token = JWT.encode(expired_payload, secret, 'HS256')

      expect do
        controller.send(:decode_jwt, expired_token)
      end.to raise_error(JWT::ExpiredSignature)
    end

    it 'raises JWT::DecodeError for invalid token' do
      expect do
        controller.send(:decode_jwt, 'invalid-token')
      end.to raise_error(JWT::DecodeError)
    end
  end

  describe '#jwt_secret' do
    it 'returns VASS jwt_secret from settings' do
      expect(controller.send(:jwt_secret)).to eq(Settings.vass.jwt_secret)
    end
  end

  describe '#decode_jwt_for_revocation' do
    let(:payload) do
      {
        sub: veteran_id,
        exp: 1.hour.from_now.to_i,
        iat: Time.current.to_i,
        jti: SecureRandom.uuid
      }
    end
    let(:token) { JWT.encode(payload, secret, 'HS256') }

    it 'decodes valid token and returns payload' do
      decoded = controller.send(:decode_jwt_for_revocation, token)
      expect(decoded['sub']).to eq(veteran_id)
    end

    it 'decodes expired token without raising error' do
      expired_payload = payload.merge(exp: 1.hour.ago.to_i)
      expired_token = JWT.encode(expired_payload, secret, 'HS256')

      decoded = controller.send(:decode_jwt_for_revocation, expired_token)
      expect(decoded['sub']).to eq(veteran_id)
    end

    it 'returns nil for invalid token format' do
      decoded = controller.send(:decode_jwt_for_revocation, 'invalid-token')
      expect(decoded).to be_nil
    end

    it 'returns nil for token with wrong signature' do
      wrong_secret_token = JWT.encode(payload, 'wrong-secret', 'HS256')
      decoded = controller.send(:decode_jwt_for_revocation, wrong_secret_token)
      expect(decoded).to be_nil
    end

    it 'logs decode error for invalid token' do
      expect(Rails.logger).to receive(:warn)
        .with(a_string_including('"action":"auth_failure"', '"reason":"revocation_decode_error"',
                                 '"error_class":"JWT::DecodeError"'))
      controller.send(:decode_jwt_for_revocation, 'invalid-token')
    end

    it 'logs decode error for wrong signature' do
      wrong_secret_token = JWT.encode(payload, 'wrong-secret', 'HS256')
      expect(Rails.logger).to receive(:warn)
        .with(a_string_including('"action":"auth_failure"', '"reason":"revocation_decode_error"',
                                 '"error_class":"JWT::VerificationError"'))
      controller.send(:decode_jwt_for_revocation, wrong_secret_token)
    end
  end

  describe '#audit_metadata' do
    context 'when jti is present' do
      let(:jti) { SecureRandom.uuid }
      let(:payload) do
        {
          sub: veteran_id,
          exp: 1.hour.from_now.to_i,
          iat: Time.current.to_i,
          jti:
        }
      end
      let(:token) { JWT.encode(payload, secret, 'HS256') }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
        get :index
      end

      it 'returns hash with jti' do
        expect(controller.audit_metadata).to eq({ jti: })
      end
    end

    context 'when jti is not present' do
      it 'returns empty hash' do
        expect(controller.audit_metadata).to eq({})
      end
    end

    context 'when authentication failed' do
      before do
        request.headers['Authorization'] = 'Bearer invalid-token'
        get :index
      end

      it 'returns empty hash' do
        expect(controller.audit_metadata).to eq({})
      end
    end
  end
end
