# frozen_string_literal: true

require 'rails_helper'
require 'saml/settings_service'

RSpec.describe SAML::SettingsService do
  it '#metadata should use mock_saml_idp' do
    metadata = SAML::SettingsService.metadata
    service = MockSaml::IdpService.new
    response = service.sso_saml_response
    puts Base64.decode64(response)
    binding.pry
  end
end
