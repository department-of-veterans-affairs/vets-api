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
        redis_otc_expiry: 600,
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

  describe 'POST #request_otc' do
    let(:params) do
      {
        session: {
          uuid:,
          last_name:,
          dob: date_of_birth
        }
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
        allow(session_model).to receive(:generate_and_save_otc).and_return('123456')
        allow(redis_client).to receive(:increment_rate_limit)
        allow(redis_client).to receive_messages(rate_limit_exceeded?: false, validation_rate_limit_exceeded?: false,
                                                redis_otc_expiry: 15)
        allow(vanotify_service).to receive(:send_otp)
        allow(appointments_service).to receive(:get_veteran_info).and_return(
          veteran_data.merge('contact_method' => 'email', 'contact_value' => valid_email)
        )
        allow(session_model).to receive(:save_veteran_metadata_for_session)
      end

      it 'returns success response' do
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['message']).to eq('OTC sent to registered email address')
        expect(json_response['data']['expiresIn']).to be_a(Integer)
      end

      it 'validates and fetches veteran info from VASS' do
        expect(appointments_service).to receive(:get_veteran_info).with(
          veteran_id: uuid
        )
        post :request_otc, params:, format: :json
      end

      it 'sets contact info from veteran data' do
        expect(session_model).to receive(:set_contact_from_veteran_data).with(
          hash_including('contact_method' => 'email', 'contact_value' => valid_email)
        )
        post :request_otc, params:, format: :json
      end

      it 'generates and saves OTC, then sends via VANotify' do
        expect(session_model).to receive(:generate_and_save_otc).and_return('123456')
        expect(vanotify_service).to receive(:send_otp).with(
          contact_method: 'email',
          contact_value: valid_email,
          otp_code: '123456'
        )
        post :request_otc, params:, format: :json
      end

      it 'increments rate limit counter by UUID' do
        expect(redis_client).to receive(:increment_rate_limit).with(identifier: uuid)
        post :request_otc, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otc_generated',
                                                   tags: ['service:vass'])
        post :request_otc, params:, format: :json
      end
    end

    context 'with invalid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_creation?: false)
      end

      it 'returns unprocessable entity status' do
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end

      it 'does not fetch veteran info' do
        expect(appointments_service).not_to receive(:get_veteran_info)
        post :request_otc, params:, format: :json
      end

      it 'does not generate OTC' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otc, params:, format: :json
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
        post :request_otc, params:, format: :json
        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end

      it 'does not fetch veteran info when rate limited' do
        expect(appointments_service).not_to receive(:get_veteran_info)
        begin
          post :request_otc, params:, format: :json
        rescue Vass::Errors::RateLimitError
          # Expected
        end
      end

      it 'logs rate limit exceeded' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.rate_limit_exceeded',
                                                   tags: ['service:vass'])
        begin
          post :request_otc, params:, format: :json
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
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('service_error')
      end

      it 'does not generate OTC' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otc, params:, format: :json
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
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('invalid_credentials')
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otc, params:, format: :json
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
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['code']).to eq('missing_contact_info')
        expect(json_response['errors'].first['detail']).to eq('No contact information available for this veteran.')
      end

      it 'does not generate OTP' do
        expect(session_model).not_to receive(:generate_otp)
        post :request_otc, params:, format: :json
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
        allow(session_model).to receive(:generate_and_save_otc).and_return('123456')
        allow(vanotify_service).to receive(:send_otp).and_raise(
          VANotify::Error.new(500, 'VANotify service unavailable')
        )
      end

      it 'returns bad gateway status' do
        post :request_otc, params:, format: :json

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('notification_error')
      end

      it 'logs VANotify error' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            '"service":"vass"', '"action":"vanotify_error"', "\"uuid\":\"#{uuid}\"",
            '"error_class":"VANotify::Error"', '"status_code":500', '"contact_method":"email"'
          )
        )
        post :request_otc, params:, format: :json
      end

      it 'increments StatsD metric for failed OTC send' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otc_send_failed',
                                                   tags: ['service:vass'])
        post :request_otc, params:, format: :json
      end

      context 'with different VANotify error status codes' do
        before do
          allow(session_model).to receive(:generate_and_save_otc).and_return('123456')
        end

        it 'returns bad request for 400 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(400, 'Bad request'))
          post :request_otc, params:, format: :json
          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end

        it 'returns too many requests for 429 error' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(429, 'Rate limit exceeded'))
          post :request_otc, params:, format: :json
          expect(response).to have_http_status(:too_many_requests)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end

        it 'returns service unavailable for unknown status codes' do
          allow(vanotify_service).to receive(:send_otp).and_raise(VANotify::Error.new(999, 'Unknown error'))
          post :request_otc, params:, format: :json
          expect(response).to have_http_status(:service_unavailable)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end
    end
  end

  describe 'POST #authenticate_otc' do
    let(:jwt_token) { 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token' }
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

    context 'with valid OTC' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          valid_otc?: true,
          otc_expired?: false,
          validate_and_generate_jwt: jwt_token,
          uuid:
        )
        allow(session_model).to receive(:create_authenticated_session).and_return(true)
        allow(redis_client).to receive(:validation_rate_limit_exceeded?).and_return(false)
        allow(redis_client).to receive(:reset_validation_rate_limit)
      end

      it 'returns success response with JWT token' do
        post :authenticate_otc, params:, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['token']).to eq(jwt_token)
        expect(json_response['data']['tokenType']).to eq('Bearer')
        expect(json_response['data']['expiresIn']).to eq(3600)
      end

      it 'creates authenticated session with veteran data' do
        expect(session_model).to receive(:create_authenticated_session).with(token: jwt_token)
        post :authenticate_otc, params:, format: :json
      end

      it 'validates and generates JWT' do
        expect(session_model).to receive(:validate_and_generate_jwt).and_return(jwt_token)
        post :authenticate_otc, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otc_authentication_success',
                                                   tags: ['service:vass'])
        post :authenticate_otc, params:, format: :json
      end
    end

    context 'with invalid OTC' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(
          valid_for_validation?: true,
          otc_expired?: false,
          uuid:
        )
        allow(session_model).to receive(:validate_and_generate_jwt)
          .and_raise(Vass::Errors::AuthenticationError, 'Invalid OTC')
        allow(redis_client).to receive(:increment_validation_rate_limit)
        allow(redis_client).to receive_messages(validation_rate_limit_exceeded?: false,
                                                validation_attempts_remaining: 2)
      end

      it 'returns unauthorized status' do
        post :authenticate_otc, params:, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'][0]['code']).to eq('invalid_otc')
      end

      it 'does not delete the OTC' do
        expect(session_model).not_to receive(:delete_otp)
        post :authenticate_otc, params:, format: :json
      end

      it 'logs StatsD metric' do
        expect(StatsD).to receive(:increment).with('api.vass.sessions.otc_validation_failed',
                                                   tags: ['service:vass'])
        post :authenticate_otc, params:, format: :json
      end
    end

    context 'with invalid parameters' do
      before do
        allow(Vass::V0::Session).to receive(:build).and_return(session_model)
        allow(session_model).to receive_messages(valid_for_validation?: false, uuid:)
        allow(redis_client).to receive_messages(validation_rate_limit_exceeded?: false, validation_rate_limit_count: 0)
      end

      it 'returns unprocessable entity status' do
        post :authenticate_otc, params:, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end

      it 'does not validate OTC' do
        expect(session_model).not_to receive(:valid_otc?)
        post :authenticate_otc, params:, format: :json
      end
    end
  end

  describe 'private methods' do
    describe '#permitted_params' do
      it 'permits session attributes' do
        params = {
          session: {
            uuid:,
            last_name:,
            dob: date_of_birth
          }
        }
        controller.params = ActionController::Parameters.new(params)
        permitted = controller.send(:permitted_params)
        expect(permitted).to be_permitted
        expect(permitted[:uuid]).to eq(uuid)
        expect(permitted[:last_name]).to eq(last_name)
        expect(permitted[:dob]).to eq(date_of_birth)
      end
    end
  end
end
