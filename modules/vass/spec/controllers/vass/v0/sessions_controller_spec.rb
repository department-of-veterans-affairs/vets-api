# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::V0::SessionsController, type: :controller do
  routes { Vass::Engine.routes }

  let(:redis_client) { instance_double(Vass::RedisClient) }
  let(:session_model) { instance_double(Vass::V0::Session) }
  let(:vanotify_service) { instance_double(Vass::VANotifyService) }
  let(:appointments_service) { instance_double(Vass::AppointmentsService) }
  let(:valid_email) { 'veteran@example.com' }
  let(:valid_phone) { '5555551234' }
  let(:uuid) { SecureRandom.uuid }
  let(:otp_code) { '123456' }
  let(:session_token) { SecureRandom.uuid }
  let(:last_name) { 'Smith' }
  let(:date_of_birth) { '1990-01-15' }
  let(:edipi) { '1234567890' }

  before do
    allow(Settings).to receive(:vass).and_return(
      OpenStruct.new(
        jwt_secret: 'test-jwt-secret',
        redis_otp_expiry: 600,
        redis_session_expiry: 7200,
        redis_token_expiry: 3540,
        rate_limit_max_attempts: 5,
        rate_limit_expiry: 900
      )
    )
    allow(Vass::RedisClient).to receive(:build).and_return(redis_client)
    allow(Vass::VANotifyService).to receive(:build).and_return(vanotify_service)
    allow(Vass::AppointmentsService).to receive(:build).and_return(appointments_service)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe 'POST #request_otp' do
    let(:params) do
      {
        uuid:,
        last_name:,
        dob: date_of_birth
      }
    end

    let(:veteran_data) do
      {
        'success' => true,
        'data' => {
          'firstName' => 'John',
          'lastName' => 'Smith',
          'dateOfBirth' => '1/15/1990',
          'edipi' => edipi,
          'notificationEmail' => valid_email,
          'notificationSMS' => nil
        }
      }
    end

    context 'with valid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive(:save_otp)
        allow(session_model).to receive_messages(
          valid_for_creation?: true,
          uuid:,
          last_name:,
          date_of_birth:,
          contact_value: valid_email,
          contact_method: 'email',
          generate_otp: otp_code
        )
        allow(session_model).to receive(:set_contact_from_veteran_data)
        allow(session_model).to receive(:validate_identity_against_veteran_data)
        allow(session_model).to receive(:generate_and_save_otp).and_return('123456')
        allow(redis_client).to receive(:increment_rate_limit)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, validation_rate_limit_exceeded?: false,
                                                redis_otp_expiry: 15)
        allow(vanotify_service).to receive(:send_otp)
        allow(appointments_service).to receive(:get_veteran_info).and_return(
          veteran_data.merge('contact_method' => 'email', 'contact_value' => valid_email)
        )
        allow(session_model).to receive(:save_veteran_metadata_for_session)
      end

      it 'returns success response with obfuscated email' do
        post :request_otp, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['message']).to eq('OTP sent to registered email address')
        expect(json_response['data']['expiresIn']).to be_a(Integer)
        expect(json_response['data']['email']).to eq('v******@example.com')
      end

      it 'validates and fetches veteran info from VASS' do
        expect(appointments_service).to receive(:get_veteran_info).with(
          veteran_id: uuid
        )
        post :request_otp, params:, format: :json
      end

      it 'sets contact info from veteran data' do
        expect(session_model).to receive(:set_contact_from_veteran_data).with(
          hash_including('contact_method' => 'email', 'contact_value' => valid_email)
        )
        post :request_otp, params:, format: :json
      end

      it 'generates and saves OTP, then sends via VANotify' do
        expect(session_model).to receive(:generate_and_save_otp).and_return('123456')
        expect(vanotify_service).to receive(:send_otp).with(
          contact_method: 'email',
          contact_value: valid_email,
          otp_code: '123456'
        )
        post :request_otp, params:, format: :json
      end

      it 'increments rate limit counter by UUID' do
        expect(redis_client).to receive(:increment_rate_limit).with(identifier: uuid)
        post :request_otp, params:, format: :json
      end
    end

    context 'with missing parameters' do
      it 'returns bad request status when uuid is missing' do
        invalid_params = { last_name:, dob: date_of_birth }
        post :request_otp, params: invalid_params, format: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['code']).to eq('missing_parameter')
        expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
      end

      it 'does not fetch veteran info when parameters are missing' do
        invalid_params = { last_name:, dob: date_of_birth }
        expect(appointments_service).not_to receive(:get_veteran_info)
        post :request_otp, params: invalid_params, format: :json
      end
    end

    context 'when rate limit exceeded' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: true, uuid:)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: true, validation_rate_limit_exceeded?: false)
        allow(Settings).to receive(:vass).and_return(OpenStruct.new(rate_limit_expiry: 12))
      end

      it 'returns too many requests status' do
        post :request_otp, params:, format: :json
        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end

      it 'does not fetch veteran info when rate limited' do
        expect(appointments_service).not_to receive(:get_veteran_info)
        begin
          post :request_otp, params:, format: :json
        rescue Vass::Errors::RateLimitError
          # Expected
        end
      end

      it 'logs rate limit exceeded' do
        expect(StatsD).to receive(:increment).with('api.vass.infrastructure.rate_limit.generation.exceeded',
                                                   tags: ['service:vass'])
        begin
          post :request_otp, params:, format: :json
        rescue Vass::Errors::RateLimitError
          # Expected
        end
      end
    end

    context 'when VASS API fails' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: true, uuid:, last_name:, date_of_birth:)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, validation_rate_limit_exceeded?: false)
        allow(appointments_service).to receive(:get_veteran_info).and_raise(
          Vass::Errors::VassApiError.new('Unable to retrieve veteran information')
        )
      end

      it 'returns bad gateway status' do
        post :request_otp, params:, format: :json

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('service_error')
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otp, params:, format: :json
      end
    end

    context 'when identity validation fails' do
      let(:veteran_data_mismatch) do
        {
          'success' => true,
          'data' => {
            'firstName' => 'John',
            'lastName' => 'Doe', # Different from request
            'dateOfBirth' => '1/15/1990',
            'edipi' => edipi,
            'notificationEmail' => valid_email,
            'notificationSMS' => nil
          }
        }
      end

      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: true, uuid:, last_name:, date_of_birth:)
        allow(session_model).to receive(:validate_identity_against_veteran_data).and_raise(
          Vass::Errors::IdentityValidationError.new('Veteran identity could not be verified')
        )
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, validation_rate_limit_exceeded?: false)
        allow(redis_client).to receive(:increment_rate_limit)
        allow(appointments_service).to receive(:get_veteran_info).and_return(veteran_data_mismatch)
      end

      it 'returns unauthorized status' do
        post :request_otp, params:, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('invalid_credentials')
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otp, params:, format: :json
      end
    end

    context 'when contact info is missing' do
      let(:veteran_data_no_contact) do
        {
          'success' => true,
          'data' => {
            'firstName' => 'John',
            'lastName' => 'Smith',
            'dateOfBirth' => '1/15/1990',
            'edipi' => edipi,
            'notificationEmail' => nil,
            'notificationSMS' => nil
          }
        }
      end

      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: true, uuid:, last_name:, date_of_birth:)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, rate_limit_count: 0,
                                                validation_rate_limit_exceeded?: false, validation_rate_limit_count: 0)
        allow(appointments_service).to receive(:get_veteran_info).and_raise(
          Vass::Errors::MissingContactInfoError.new('Veteran contact information not found')
        )
      end

      it 'returns unprocessable entity status' do
        post :request_otp, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['code']).to eq('missing_contact_info')
        expect(json_response['errors'].first['detail']).to eq('No contact information available for this veteran.')
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otp, params:, format: :json
      end
    end

    context 'when VANotify fails' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_creation?: true,
          uuid:,
          last_name:,
          date_of_birth:,
          contact_value: valid_email,
          contact_method: 'email',
          generate_otp: otp_code,
          save_otp: true,
          creation_response: {
            uuid:,
            message: 'OTP generated successfully'
          }
        )
        allow(session_model).to receive(:contact_method=).with('email')
        allow(session_model).to receive(:contact_value=).with(valid_email)
        allow(session_model).to receive(:edipi=).with(edipi)
        allow(session_model).to receive(:veteran_id=).with(uuid)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, validation_rate_limit_exceeded?: false)
        allow(redis_client).to receive(:increment_rate_limit)
        allow(appointments_service).to receive(:get_veteran_info).and_return(
          veteran_data.merge('contact_method' => 'email', 'contact_value' => valid_email)
        )
        allow(session_model).to receive(:save_veteran_metadata_for_session)
        allow(session_model).to receive(:set_contact_from_veteran_data)
        allow(session_model).to receive(:validate_identity_against_veteran_data)
        allow(session_model).to receive(:generate_and_save_otp).and_return('123456')
        allow(vanotify_service).to receive(:send_otp).and_raise(
          VANotify::Error.new(500, 'VANotify service unavailable')
        )
      end

      it 'returns bad gateway status' do
        post :request_otp, params:, format: :json

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('notification_error')
      end

      it 'logs VANotify error' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            '"service":"vass"', '"action":"vanotify_error"', "\"vass_uuid\":\"#{uuid}\"",
            '"error_class":"VANotify::Error"', '"status_code":500', '"contact_method":"email"'
          )
        )
        post :request_otp, params:, format: :json
      end

      context 'with different VANotify error status codes' do
        before do
          allow(session_model).to receive(:generate_and_save_otp).and_return('123456')
        end

        it 'returns bad request for 400 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(400, 'Bad request'))
          post :request_otp, params:, format: :json
          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end

        it 'returns too many requests for 429 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(429, 'Rate limit exceeded'))
          post :request_otp, params:, format: :json
          expect(response).to have_http_status(:too_many_requests)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end

        it 'returns service unavailable for unknown status codes' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(999, 'Unknown error'))
          post :request_otp, params:, format: :json
          expect(response).to have_http_status(:service_unavailable)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end
    end
  end

  describe 'POST #authenticate_otp' do
    let(:jwt_token) { 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token' }
    let(:jti) { SecureRandom.uuid }
    let(:jwt_result) { { token: jwt_token, jti: } }
    let(:params) do
      {
        uuid:,
        last_name:,
        dob: date_of_birth,
        otp: otp_code
      }
    end

    let(:veteran_data) do
      {
        'success' => true,
        'data' => {
          'firstName' => 'John',
          'lastName' => 'Smith',
          'dateOfBirth' => '1/15/1990',
          'edipi' => edipi,
          'notificationEmail' => valid_email,
          'notificationSMS' => nil
        }
      }
    end

    context 'with valid OTP' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          valid_otp?: true,
          otp_expired?: false,
          validate_and_generate_jwt: jwt_result,
          uuid:
        )
        allow(session_model).to receive(:create_authenticated_session).and_return(true)
        allow(redis_client).to receive_messages(validation_rate_limit_exceeded?: false,
                                                redis_session_expiry: 2.hours)
        allow(redis_client).to receive(:reset_validation_rate_limit)
      end

      it 'returns success response with JWT token' do
        post :authenticate_otp, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['token']).to eq(jwt_token)
        expect(json_response['data']['tokenType']).to eq('Bearer')
        expect(json_response['data']['expiresIn']).to eq(2.hours.to_i)
      end

      it 'creates authenticated session with jti' do
        expect(session_model).to receive(:create_authenticated_session).with(jti:)
        post :authenticate_otp, params:, format: :json
      end

      it 'validates and generates JWT and returns hash with token and jti' do
        expect(session_model).to receive(:validate_and_generate_jwt).and_return(jwt_result)
        post :authenticate_otp, params:, format: :json
      end
    end

    context 'with invalid OTP' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          otp_expired?: false,
          uuid:
        )
        allow(session_model).to receive(:validate_and_generate_jwt)
          .and_raise(Vass::Errors::AuthenticationError, 'Invalid OTP')
        allow(redis_client).to receive(:increment_validation_rate_limit)
        allow(redis_client).to receive_messages(validation_rate_limit_exceeded?: false,
                                                validation_attempts_remaining: 2)
      end

      it 'returns unauthorized status' do
        post :authenticate_otp, params:, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('invalid_otp')
      end

      it 'does not delete the OTP' do
        expect(session_model).not_to receive(:delete_otp)
        post :authenticate_otp, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.infrastructure.session.otp.invalid',
                                                   tags: ['service:vass'])
        post :authenticate_otp, params:, format: :json
      end
    end

    context 'with missing parameters' do
      before do
        allow(redis_client).to receive_messages(validation_rate_limit_exceeded?: false, validation_rate_limit_count: 0)
      end

      it 'returns bad request status when otp is missing' do
        invalid_params = {
          uuid:,
          last_name:,
          dob: date_of_birth
        }
        post :authenticate_otp, params: invalid_params, format: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['code']).to eq('missing_parameter')
        expect(json_response['errors'].first['detail']).to eq('Required parameter is missing')
      end
    end
  end

  describe 'private methods' do
    describe '#permitted_params' do
      it 'permits session attributes' do
        params = {
          uuid:,
          last_name:,
          dob: date_of_birth
        }
        controller.params = ActionController::Parameters.new(params)
        permitted = controller.send(:permitted_params)
        expect(permitted).to be_permitted
        expect(permitted[:uuid]).to eq(uuid)
        expect(permitted[:last_name]).to eq(last_name)
        expect(permitted[:dob]).to eq(date_of_birth)
      end
    end

    describe '#obfuscate_email' do
      it 'obfuscates email showing first character and domain' do
        expect(controller.send(:obfuscate_email, 'veteran@example.com')).to eq('v******@example.com')
        expect(controller.send(:obfuscate_email, 'ab@domain.com')).to eq('a*@domain.com')
        expect(controller.send(:obfuscate_email, 'a@domain.com')).to eq('a@domain.com')
      end

      it 'returns nil for invalid inputs' do
        expect(controller.send(:obfuscate_email, nil)).to be_nil
        expect(controller.send(:obfuscate_email, '')).to be_nil
        expect(controller.send(:obfuscate_email, 'invalid')).to be_nil
        expect(controller.send(:obfuscate_email, '@domain.com')).to be_nil
      end
    end
  end
end
