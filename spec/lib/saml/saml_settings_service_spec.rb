# frozen_string_literal: true

require 'rails_helper'
require 'saml/settings_service'
require 'lib/sentry_logging_spec_helper'

RSpec.describe SAML::SettingsService do
  before do
    # stub out the sleep call to increase rspec speed
    allow(SAML::SettingsService).to receive(:sleep)
  end

  describe '.saml_settings' do
    context 'with a 200 response' do
      it 'should only ever make 1 external web call' do
        VCR.use_cassette('saml/idp_metadata') do
          SAML::SettingsService.merged_saml_settings(true)
          SAML::SettingsService.saml_settings
          SAML::SettingsService.saml_settings
          expect(a_request(:get, Settings.saml.metadata_url)).to have_been_made.at_most_once
        end
      end
      it 'returns a settings instance' do
        VCR.use_cassette('saml/idp_metadata') do
          expect(SAML::SettingsService.merged_saml_settings(true)).to be_an_instance_of(OneLogin::RubySaml::Settings)
        end
      end
    end
    context 'with metadata 500 responses' do
      before do
        stub_request(:get, Settings.saml.metadata_url).to_return(
          status: 500, body: 'bad news bears'
        )
      end
      it 'should log three attempts' do
        expect(Rails.logger).to receive(:warn).exactly(2).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
        expect(Rails.logger).to receive(:error).exactly(1).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
        SAML::SettingsService.merged_saml_settings(true)
      end
      it 'should keep making GET calls to fetch metadata' do
        SAML::SettingsService.merged_saml_settings(true)
        SAML::SettingsService.saml_settings
        SAML::SettingsService.saml_settings
        expect(a_request(:get, Settings.saml.metadata_url)).to have_been_made.times(9)
      end
    end
    context 'when a parsing error occurs' do
      it 'should log and reraise the error' do
        stub_request(:get, Settings.saml.metadata_url).to_return(status: 200, body: '<xml></')
        expect(Rails.logger).to receive(:error).once
        expect { SAML::SettingsService.merged_saml_settings(true) }.to raise_error(REXML::ParseException)
      end
    end
  end
end
