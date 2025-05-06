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
    let(:faraday) { double('Faraday::Connection') }

    it 'creates a new Faraday connection with the correct base path' do
      expect(Faraday).to receive(:new).with("#{token_url}/")
      subject.connection
    end

    it 'creates the connection' do
      allow(Faraday).to receive(:new).and_yield(faraday)

      expect(faraday).to receive(:use).once.with(:breakers, { service_name: subject.service_name })
      expect(faraday).to receive(:request).once.with(:instrumentation,
                                                     { name: 'CARMA::Client::MuleSoftAuthTokenConfiguration' })
      expect(faraday).to receive(:adapter).once.with(Faraday.default_adapter)

      subject.connection
    end
  end

  it 'service_name returns class name' do
    expect(subject.service_name).to eq('CARMA::Client::MuleSoftAuthTokenConfiguration')
  end

  describe 'timeout' do
    context 'has a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.auth).to receive(:timeout).and_return(23)
      end

      it 'returns the configured value' do
        expect(subject.timeout).to eq(23)
      end
    end

    context 'does not have a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.auth).to receive(:key?).and_return(nil)
      end

      it 'returns the default value' do
        expect(subject.timeout).to eq(30)
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
end
