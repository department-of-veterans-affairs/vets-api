# frozen_string_literal: true

require 'rails_helper'
require 'saml/ssoe_settings_service'
require 'lib/sentry_logging_spec_helper'

RSpec.describe SAML::SSOeSettingsService do
  before do
    # stub out the sleep call to increase rspec speed
    allow(SAML::SSOeSettingsService).to receive(:sleep)
  end

  describe '.saml_settings' do
    context 'with a 200 response', vcr: { cassette_name: 'saml/idp_metadata' } do
      it 'should only ever make 1 external web call' do
        SAML::SSOeSettingsService.merged_saml_settings(true)
        SAML::SSOeSettingsService.saml_settings
        SAML::SSOeSettingsService.saml_settings
        expect(a_request(:get, Settings.saml_ssoe.metadata_url)).to have_been_made.at_most_once
      end
      it 'returns a settings instance' do
        expect(SAML::SSOeSettingsService.merged_saml_settings(true)).to be_an_instance_of(OneLogin::RubySaml::Settings)
      end
      it 'overrides name-id to be "persistent"' do
        expect(SAML::SSOeSettingsService.merged_saml_settings(true).name_identifier_format)
          .to eq('urn:oasis:names:tc:SAML:2.0:nameid-format:persistent')
      end
    end
    context 'with metadata 500 responses' do
      before do
        stub_request(:get, Settings.saml_ssoe.metadata_url).to_return(
          status: 500, body: 'bad news bears'
        )
      end
      it 'should log three attempts' do
        expect(Rails.logger).to receive(:warn).exactly(2).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
        expect(Rails.logger).to receive(:error).exactly(1).times.with(/Failed to load SAML metadata: 500: try \d of 3/)
        SAML::SSOeSettingsService.merged_saml_settings(true)
      end
      it 'should keep making GET calls to fetch metadata' do
        SAML::SSOeSettingsService.merged_saml_settings(true)
        SAML::SSOeSettingsService.saml_settings
        SAML::SSOeSettingsService.saml_settings
        expect(a_request(:get, Settings.saml_ssoe.metadata_url)).to have_been_made.times(9)
      end
    end
    context 'when a parsing error occurs' do
      it 'should log and reraise the error' do
        stub_request(:get, Settings.saml_ssoe.metadata_url).to_return(status: 200, body: '<xml></')
        expect(Rails.logger).to receive(:error).once
        expect { SAML::SSOeSettingsService.merged_saml_settings(true) }.to raise_error(REXML::ParseException)
      end
    end
  end
end
