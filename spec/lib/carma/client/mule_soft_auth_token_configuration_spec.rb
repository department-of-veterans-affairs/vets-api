# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_auth_token_configuration'

describe CARMA::Client::MuleSoftAuthTokenConfiguration do
  subject { described_class.instance }

  let(:token_url) { 'https://www.somesite.gov' }

  before do
    allow(Settings.form_10_10cg.carma.mulesoft.auth).to receive(:token_url).and_return(token_url)
  end

  describe 'connection' do
    subject { super().connection }

    it 'sets url prefix' do
      expect(subject.url_prefix.to_s).to eq("#{token_url}/")
    end
  end

  describe 'service_name' do
    subject { super().service_name }

    it 'returns class name' do
      expect(subject).to eq('CARMA::Client::MuleSoftAuthTokenConfiguration')
    end
  end

  describe 'timeout' do
    subject { super().timeout }

    context 'has a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.auth).to receive(:timeout).and_return(23)
      end

      it 'returns the configured value' do
        expect(subject).to eq(23)
      end
    end

    context 'does not have a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.auth).to receive(:key?).and_return(nil)
      end

      it 'returns the default value' do
        expect(subject).to eq(30)
      end
    end
  end

  describe 'settings' do
    let(:expected_settings) { 'my_fake_settings_value' }

    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:auth).and_return(expected_settings)
    end

    it 'returns expected settings path' do
      expect(subject.settings).to eq(expected_settings)
    end
  end

  describe 'base_path' do
    subject { super().send(:base_path) }

    it 'returns the correct value' do
      expect(subject).to eq("#{token_url}/")
    end
  end
end
