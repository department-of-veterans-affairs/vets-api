# frozen_string_literal: true

require 'rails_helper'
require 'saml/settings_service'
require 'saml/health_status'

RSpec.describe SAML::HealthStatus do
  subject { described_class }

  before do
    # stub out the sleep call to increase rspec speed
    allow(SAML::SettingsService).to receive(:sleep)
  end

  context 'with a 200 response' do
    before do
      VCR.use_cassette('saml/idp_metadata') do
        SAML::SettingsService.merged_saml_settings(true)
      end
    end
    it '.healthy? returns true' do
      expect(subject.healthy?).to eq(true)
    end
    it '.error_message is blank' do
      VCR.use_cassette('saml/idp_metadata') do
        expect(subject.error_message).to eq('')
      end
    end
  end

  context 'retrieve not yet attempted' do
    before do
      allow(subject).to receive(:fetch_attempted?) { false }
    end

    it '.healthy? returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns NOT_ATTEMPTED' do
      expect(subject.error_message).to eq(SAML::StatusMessages::NOT_ATTEMPTED)
    end
  end

  context 'IDP metadata not found' do
    before do
      # to regenerate: change saml.metadata_url in settings.local.yml to be invalid
      VCR.use_cassette('saml/idp_metadata_404') do
        SAML::SettingsService.merged_saml_settings(true)
      end
    end
    it '.healthy? returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns MISSING' do
      expect(subject.error_message).to eq(SAML::StatusMessages::MISSING)
    end
  end

  context 'IDP cert invalid' do
    before do
      # to regenerate: make copy of valid metadata response 'idp_metadata.yml' &
      # copy the contents of invalid_idme_cert.crt into:
      # <md:IDPSSODescriptor><<md:KeyDescriptor><ds:KeyInfo><ds:X509Data><ds:X509Certificate>
      # fun fact: invalid_idme_cert.crt is an actual cert id.me served in prod (it contains /r chars)
      VCR.use_cassette('saml/idp_metadata_bad_cert') do
        SAML::SettingsService.merged_saml_settings(true)
      end
    end
    it '.healthy? returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns CERT_INVALID' do
      expect(subject.error_message).to eq(SAML::StatusMessages::CERT_INVALID)
    end
  end
end
