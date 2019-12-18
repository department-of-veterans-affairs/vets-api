# frozen_string_literal: true

require 'rails_helper'
require 'saml/ssoe_settings_service'

RSpec.describe SAML::SSOeSettingsService do
  before { Settings.saml_ssoe.idp_metadata_file = Rails.root.join('spec', 'support', 'saml', 'test_idp_metadata.xml') }

  describe '.saml_settings' do
    it 'returns a settings instance' do
      expect(SAML::SSOeSettingsService.saml_settings).to be_an_instance_of(OneLogin::RubySaml::Settings)
    end
    it 'allows override of provided settings' do
      settings = SAML::SSOeSettingsService.saml_settings('issuer' => 'testIssuer')
      expect(settings.issuer).to equal('testIssuer')
    end
  end
end
