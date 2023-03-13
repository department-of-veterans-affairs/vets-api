# frozen_string_literal: true

require 'rails_helper'
require 'saml/ssoe_settings_service'

RSpec.describe SAML::SSOeSettingsService do
  before do
    allow(Settings.saml_ssoe)
      .to receive(:idp_metadata_file).and_return(Rails.root.join('spec', 'support', 'saml', 'test_idp_metadata.xml'))
  end

  describe '.saml_settings' do
    it 'returns a settings instance' do
      expect(SAML::SSOeSettingsService.saml_settings).to be_an_instance_of(OneLogin::RubySaml::Settings)
    end

    it 'allows override of provided settings' do
      settings = SAML::SSOeSettingsService.saml_settings('sp_entity_id' => 'testIssuer')
      expect(settings.sp_entity_id).to equal('testIssuer')
    end

    context 'with no signing or encryption configured' do
      it 'omits certificate from settings' do
        with_settings(Settings.saml_ssoe, certificate: 'foobar',
                                          request_signing: false, response_signing: false,
                                          response_encryption: false) do
          expect(SAML::SSOeSettingsService.saml_settings.certificate).to be_nil
        end
      end
    end

    context 'with signing configured' do
      it 'includes certificate in settings' do
        with_settings(Settings.saml_ssoe, certificate: 'foobar',
                                          request_signing: true, response_signing: false,
                                          response_encryption: false) do
          expect(SAML::SSOeSettingsService.saml_settings.certificate).to eq('foobar')
        end
      end
    end

    context 'with encryption configured' do
      it 'includes certificate in settings' do
        with_settings(Settings.saml_ssoe, certificate: 'foobar',
                                          request_signing: false, response_signing: false,
                                          response_encryption: true) do
          expect(SAML::SSOeSettingsService.saml_settings.certificate).to eq('foobar')
        end
      end
    end
  end
end
