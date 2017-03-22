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

  context 'retrieve not yet attempted' do
    before { allow(subject).to receive(:fetch_attempted?) { false } }
    it '.healthy returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns NOT_ATTEMPTED' do
      expect(subject.error_message).to eq(SAML::StatusMessages::NOT_ATTEMPTED)
    end
  end

  context 'IDP metadata found' do
    before do
      stub_request(:get, Settings.saml.metadata_url).to_return(
        status: 500, body: 'bad news bears'
      )
      SAML::SettingsService.merged_saml_settings(true)
    end
    it '.healthy returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns MISSING' do
      expect(subject.error_message).to eq(SAML::StatusMessages::MISSING)
    end
  end

  context 'IDP cert invalid' do
    let(:invalid_cert_saml_settings) { build(:rubysaml_settings, :invalid_cert) }
    before do
      allow(SAML::SettingsService).to receive(:fetch_attempted) { true }
      allow(SAML::SettingsService).to receive(:merged_saml_settings) { invalid_cert_saml_settings }
    end
    it '.healthy returns false' do
      expect(subject.healthy?).to eq(false)
    end
    it '.error_message returns CERT_INVALID' do
      expect(subject.error_message).to eq(SAML::StatusMessages::CERT_INVALID)
    end
  end
end
