# frozen_string_literal: true

require 'rails_helper'
require 'config_helper'

RSpec.describe ConfigHelper do
  let(:config) { double('config') }
  let(:action_mailer) { double('action_mailer') }

  before do
    allow(config).to receive(:action_mailer).and_return(action_mailer)
    allow(action_mailer).to receive(:preview_paths=)
    allow(action_mailer).to receive(:show_previews=)
    allow(action_mailer).to receive(:delivery_method=)
    allow(action_mailer).to receive(:govdelivery_tms_settings=)
  end

  describe '.setup_action_mailer' do
    it 'sets preview paths correctly' do
      expect(action_mailer).to receive(:preview_paths=).with([Rails.root.join('spec', 'mailers', 'previews')])

      described_class.setup_action_mailer(config)
    end

    context 'when in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(FeatureFlipper).to receive(:staging_email?).and_return(false)
      end

      it 'enables show_previews' do
        expect(action_mailer).to receive(:show_previews=).with(true)

        described_class.setup_action_mailer(config)
      end
    end

    context 'when staging_email feature is enabled' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(FeatureFlipper).to receive(:staging_email?).and_return(true)
      end

      it 'enables show_previews' do
        expect(action_mailer).to receive(:show_previews=).with(true)

        described_class.setup_action_mailer(config)
      end
    end

    context 'when neither development nor staging_email' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(FeatureFlipper).to receive(:staging_email?).and_return(false)
      end

      it 'disables show_previews' do
        expect(action_mailer).to receive(:show_previews=).with(false)

        described_class.setup_action_mailer(config)
      end
    end

    context 'when send_email feature is enabled' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(Settings).to receive(:govdelivery).and_return(
          double(token: 'test_token', server: 'api.govdelivery.com')
        )
      end

      it 'configures govdelivery_tms delivery method' do
        expect(action_mailer).to receive(:delivery_method=).with(:govdelivery_tms)

        described_class.setup_action_mailer(config)
      end

      it 'sets govdelivery_tms_settings with correct values' do
        expected_settings = {
          auth_token: 'test_token',
          api_root: 'https://api.govdelivery.com'
        }

        expect(action_mailer).to receive(:govdelivery_tms_settings=).with(expected_settings)

        described_class.setup_action_mailer(config)
      end
    end

    context 'when send_email feature is disabled' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(false)
      end

      it 'does not set delivery method' do
        expect(action_mailer).not_to receive(:delivery_method=)

        described_class.setup_action_mailer(config)
      end

      it 'does not set govdelivery_tms_settings' do
        expect(action_mailer).not_to receive(:govdelivery_tms_settings=)

        described_class.setup_action_mailer(config)
      end
    end

    context 'integration test with both features enabled' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(FeatureFlipper).to receive(:staging_email?).and_return(false)
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(Settings).to receive(:govdelivery).and_return(
          double(token: 'integration_token', server: 'staging.govdelivery.com')
        )
      end

      it 'configures all settings correctly' do
        expect(action_mailer).to receive(:preview_paths=).with([Rails.root.join('spec', 'mailers', 'previews')])
        expect(action_mailer).to receive(:show_previews=).with(true)
        expect(action_mailer).to receive(:delivery_method=).with(:govdelivery_tms)
        expect(action_mailer).to receive(:govdelivery_tms_settings=).with({
          auth_token: 'integration_token',
          api_root: 'https://staging.govdelivery.com'
        })

        described_class.setup_action_mailer(config)
      end
    end

    context 'with missing settings' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(Settings).to receive(:govdelivery).and_return(
          double(token: nil, server: nil)
        )
      end

      it 'handles nil settings gracefully' do
        expected_settings = {
          auth_token: nil,
          api_root: 'https://'
        }

        expect(action_mailer).to receive(:govdelivery_tms_settings=).with(expected_settings)

        described_class.setup_action_mailer(config)
      end
    end
  end
end