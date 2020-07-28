# frozen_string_literal: true

require 'rails_helper'
require 'saml/ssoe_settings_service'
require 'lib/sentry_logging_spec_helper'

RSpec.describe SAML::SSOeSettingsService do
  before { Settings.saml_ssoe.idp_metadata_file = Rails.root.join('spec', 'support', 'saml', 'test_idp_metadata.xml') }

  describe '.saml_settings' do
    it 'returns a settings instance' do
      expect(SAML::SSOeSettingsService.saml_settings).to be_an_instance_of(OneLogin::RubySaml::Settings)
    end
    it 'allows override of provided settings' do
      settings = SAML::SSOeSettingsService.saml_settings('sp_entity_id' => 'testIssuer')
      expect(settings.sp_entity_id).to equal('testIssuer')
    end

    context 'with no signing or encryption configured' do
      before do
        Settings.saml_ssoe.certificate = 'foobar'
        Settings.saml_ssoe.request_signing = false
        Settings.saml_ssoe.response_signing = false
        Settings.saml_ssoe.response_encryption = false
      end

      it 'omits certificate from settings' do
        expect(SAML::SSOeSettingsService.saml_settings.certificate).to be_nil
      end
    end

    context 'with signing configured' do
      before do
        Settings.saml_ssoe.certificate = 'foobar'
        Settings.saml_ssoe.request_signing = true
        Settings.saml_ssoe.response_signing = false
        Settings.saml_ssoe.response_encryption = false
      end

      it 'includes certificate in settings' do
        expect(SAML::SSOeSettingsService.saml_settings.certificate).to eq('foobar')
      end
    end

    context 'with encryption configured' do
      before do
        Settings.saml_ssoe.certificate = 'foobar'
        Settings.saml_ssoe.request_signing = false
        Settings.saml_ssoe.response_signing = false
        Settings.saml_ssoe.response_encryption = true
      end

      it 'includes certificate in settings' do
        expect(SAML::SSOeSettingsService.saml_settings.certificate).to eq('foobar')
      end
    end
  end
end
