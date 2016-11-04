# frozen_string_literal: true
require 'rails_helper'
require 'saml/settings_service'

RSpec.describe SAML::SettingsService do
  it 'should only ever make 1 external web call' do
    stub_request(:get, SAML_CONFIG['metadata_url']).to_return(body: 'abc')
    SAML::SettingsService.new.saml_settings
    SAML::SettingsService.new.saml_settings
    SAML::SettingsService.new.saml_settings
    expect(a_request(:get, SAML_CONFIG['metadata_url'])).to have_been_made.times(1)
  end
end
