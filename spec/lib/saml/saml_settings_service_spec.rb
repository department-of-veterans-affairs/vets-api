# frozen_string_literal: true
require 'rails_helper'
require 'saml/settings_service'

RSpec.describe SAML::SettingsService do
  before(:each) do
    SAML.send(:remove_const, 'SettingsService')
    load 'lib/saml/settings_service.rb'
  end
  context 'with a 200 response' do
    it 'should only ever make 1 external web call' do
      stub_request(:get, SAML_CONFIG['metadata_url']).to_return(status: 200, body: 'abc')
      SAML::SettingsService.saml_settings
      SAML::SettingsService.saml_settings
      SAML::SettingsService.saml_settings
      expect(a_request(:get, SAML_CONFIG['metadata_url'])).to have_been_made.at_most_once
    end
  end
  context 'with metadata 500 responses' do
    it 'should log three attempts' do
      stub_request(:get, SAML_CONFIG['metadata_url']).to_return(
        status: 500, body: 'bad news bears'
      )
      expect(Rails.logger).to receive(:error).exactly(3).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
      SAML::SettingsService.saml_settings
    end
  end
end
