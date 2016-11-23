# frozen_string_literal: true
require 'rails_helper'
require 'saml/settings_service'

RSpec.describe SAML::SettingsService do
  describe '.saml_settings' do
    context 'with a 200 response' do
      it 'should only ever make 1 external web call' do
        stub_request(:get, SAML_CONFIG['metadata_url']).to_return(status: 200, body: 'abc')
        SAML::SettingsService.saml_settings
        SAML::SettingsService.saml_settings
        SAML::SettingsService.saml_settings
        expect(a_request(:get, SAML_CONFIG['metadata_url'])).to have_been_made.at_most_once
      end
      it 'returns a settings instance' do
        expect(SAML::SettingsService.saml_settings(true)).to be_an_instance_of(OneLogin::RubySaml::Settings)
      end
    end
    context 'with metadata 500 responses' do
      it 'should log three attempts' do
        stub_request(:get, SAML_CONFIG['metadata_url']).to_return(
          status: 500, body: 'bad news bears'
        )
        expect(Rails.logger).to receive(:error).exactly(3).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
        SAML::SettingsService.saml_settings(true)
      end
    end
    context 'when a parsing error occurs' do
      it 'should log and reraise the error' do
        stub_request(:get, SAML_CONFIG['metadata_url']).to_return(status: 200, body: '<xml></')
        expect(Rails.logger).to receive(:error).once
        expect { SAML::SettingsService.saml_settings(true) }.to raise_error(REXML::ParseException)
      end
    end
  end
end
