# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/vass/va_notify_service'

RSpec.describe Vass::VANotifyService do
  let(:api_key) { 'test-api-key' }
  let(:email_template_id) { 'vass-otp-email-template-id' }
  let(:notify_client) { instance_double(VaNotify::Service) }
  let(:otp_code) { '123456' }
  let(:email_address) { 'veteran@example.com' }

  before do
    # Mock Settings
    template_id_double = double
    allow(template_id_double).to receive_messages(vass_otp_email: email_template_id)

    va_gov_service_double = double
    allow(va_gov_service_double).to receive_messages(api_key:, template_id: template_id_double)

    services_double = double
    allow(services_double).to receive(:va_gov).and_return(va_gov_service_double)

    vanotify_double = double
    allow(vanotify_double).to receive(:services).and_return(services_double)

    allow(Settings).to receive(:vanotify).and_return(vanotify_double)

    # Allow initial service creation
    allow(VaNotify::Service).to receive(:new).with(api_key).and_return(notify_client)
  end

  describe '.build' do
    it 'creates a service instance' do
      service = described_class.build
      expect(service).to be_an_instance_of(Vass::VANotifyService)
    end

    it 'uses default API key from settings' do
      expect(VaNotify::Service).to receive(:new).with(api_key)
      described_class.build
    end

    it 'can use custom API key' do
      custom_api_key = 'custom-api-key'
      expect(VaNotify::Service).to receive(:new).with(custom_api_key)
      described_class.build(api_key: custom_api_key)
    end
  end

  describe '#send_otp' do
    let(:service) { described_class.build }

    context 'with email contact method' do
      it 'sends OTP via email' do
        expect(notify_client).to receive(:send_email).with(
          email_address:,
          template_id: email_template_id,
          personalisation: { otp_code: }
        )

        service.send_otp(
          contact_method: 'email',
          contact_value: email_address,
          otp_code:
        )
      end

      it 'raises error for invalid contact method' do
        expect do
          service.send_otp(
            contact_method: 'invalid',
            contact_value: email_address,
            otp_code:
          )
        end.to raise_error(ArgumentError, "Invalid contact_method: invalid. Must be 'email'")
      end
    end

    context 'when VANotify service raises an error' do
      let(:error) { VANotify::Error.new(500, 'VANotify error') }

      it 'raises the error for email' do
        allow(notify_client).to receive(:send_email).and_raise(error)

        expect do
          service.send_otp(
            contact_method: 'email',
            contact_value: email_address,
            otp_code:
          )
        end.to raise_error(VANotify::Error)
      end
    end

    context 'when template IDs are not configured' do
      it 'raises error for missing email template ID' do
        template_id_double = double
        allow(template_id_double).to receive_messages(vass_otp_email: nil)

        va_gov_service_double = double
        allow(va_gov_service_double).to receive_messages(api_key:, template_id: template_id_double)

        services_double = double
        allow(services_double).to receive(:va_gov).and_return(va_gov_service_double)

        vanotify_double = double
        allow(vanotify_double).to receive(:services).and_return(services_double)

        allow(Settings).to receive(:vanotify).and_return(vanotify_double)

        service = described_class.build

        expect do
          service.send_otp(
            contact_method: 'email',
            contact_value: email_address,
            otp_code:
          )
        end.to raise_error(ArgumentError, 'VASS OTP email template ID not configured')
      end
    end
  end
end
