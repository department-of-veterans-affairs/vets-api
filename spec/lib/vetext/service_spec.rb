# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'
require 'vetext/service'

describe 'VEText::Service' do
  let(:service) { VEText::Service.new }

  describe '#register' do
    context 'with a new device token' do
      let(:response) do
        VCR.use_cassette('vetext/register_success') do
          service.register(
              'va_mobile_app',
              '09d5a13a03b64b669f5ac0c32a0db6ad',
              '195498340',
              'ios',
              '13.1'
          )
        end
      end

      it 'returns the unique sid for the app/device/icn' do
        expect(response).to include(sid: '8E7F6585AAB1F6CF2E16058183303383')
      end
    end

    context 'when a 400 is returned' do
      it 'raises an error' do
        VCR.use_cassette('vetext/register_bad_request') do
          expect {
            service.register(
                'va_mobile_app',
                'device-token',
                'icn',
                'ios',
                '13.1'
            )
          }.to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_PUSH_400/)
        end
      end
    end
    context 'bad app_name provided' do
      it 'raises a an error' do
        VCR.use_cassette('vetext/register_success') do
          expect {
            service.register(
                'bad_app_name',
                '09d5a13a03b64b669f5ac0c32a0db6ad',
                '195498340',
                'ios',
                '13.1'
            )
          }.to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_PUSH_404/)
        end
      end
    end
  end

  context 'when a 500 is returned' do
    it 'raises an error' do
      VCR.use_cassette('vetext/register_internal_server_error') do
        expect {
          service.register(
              'va_mobile_app',
              'device-token',
              'icn',
              'ios',
              '13.1'
          )
        }.to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_PUSH_502/)
      end
    end
  end

  describe '#get_preferences' do
    let(:get_preferences_body) do
      [
          {
              "auto_opt_in": false,
              "endpoint_sid": "8c258cbe573c462f912e7dd74585a5a9",
              "preference_id": "appointment_reminders",
              "preference_name": "Appointment Reminders",
              "value": true
          }, {
              "auto_opt_in": false,
              "endpoint_sid": "8c258cbe573c462f912e7dd74585a5a9",
              "preference_id": "claim_status_updates",
              "preference_name": "Claim Status Updates",
              "value": true
          }
      ]
    end
    context 'with a valid device token' do
      let(:response) do
        VCR.use_cassette('vetext/get_preferences_success') do
          service.get_preferences('8c258cbe573c462f912e7dd74585a5a9')
        end
      end

      it 'returns the list of preferences' do
        expect(response).to eq(get_preferences_body)
      end
    end
  end

  describe '#set_preference' do
    let(:set_preference_body) do
      {
          "success": true
      }
    end
    context 'with a valid device token and preference id' do
      let(:response) do
        VCR.use_cassette('vetext/set_preference_success') do
          service.set_preference('8c258cbe573c462f912e7dd74585a5a9', 'claim_status_updates', true)
        end
      end

      it 'returns successfully' do
        expect(response).to eq(set_preference_body)
      end
    end
  end

  describe '#send_notification' do
    let(:response_body) do
      {
          "success": true
      }
    end

    let(:personalization) do
      {
          "%APPOINTMENT_DATE%": 'DEC 14',
          "%APPOINTMENT_TIME%": '10:00'
      }
    end
    context 'with a valid inputs' do
      let(:response) do
        VCR.use_cassette('vetext/send_success') do
          service.send_notification(
              '8c258cbe573c462f912e7dd74585a5a9',
              '0EF7C8C9390847D7B3B521426EFF5814',
              personalization
          )
        end
      end

      it 'returns successfully and has a 200' do
        expect(response).to eq(response_body)
      end
    end
  end
end
