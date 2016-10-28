# frozen_string_literal: true
require 'rails_helper'
require 'saml/settings_service'

RSpec.describe SAML::SettingsService do
  # testing singletons is tricky since it may be initialized in a previous spec example,
  # use this this instance variable for testing instead
  before(:each) { @service_instance = SAML::SettingsService.clone }

  it 'should only ever make 1 external web call' do
    stub_request(:get, SAML_CONFIG['metadata_url'])
    @service_instance.instance.saml_settings
    @service_instance.instance.saml_settings
    @service_instance.instance.saml_settings
    expect(a_request(:get, SAML_CONFIG['metadata_url'])).to have_been_made.times(1)
  end
end
