# frozen_string_literal: true

require 'rails_helper'
require 'mvi/service'

describe MVI::Configuration do
  describe '.ssl_options' do
    context 'when there are no SSL options' do
      before do
        allow(MVI::Configuration.instance).to receive(:ssl_cert) { nil }
        allow(MVI::Configuration.instance).to receive(:ssl_key) { nil }
      end

      it 'should return nil' do
        allow(MVI::Configuration.instance).to receive(:ssl_cert) { nil }
        allow(MVI::Configuration.instance).to receive(:ssl_key) { nil }
        expect(MVI::Configuration.instance.ssl_options).to be_nil
      end
    end
    context 'when there are SSL options' do
      let(:cert) { instance_double('OpenSSL::X509::Certificate') }
      let(:key) { instance_double('OpenSSL::PKey::RSA') }

      before do
        allow(MVI::Configuration.instance).to receive(:ssl_cert) { cert }
        allow(MVI::Configuration.instance).to receive(:ssl_key) { key }
      end

      it 'should return the wsdl, cert and key paths' do
        expect(MVI::Configuration.instance.ssl_options).to eq(
          client_cert: cert,
          client_key: key
        )
      end
    end
  end

  # TODO(knkski): These tests probably aren't doing anything useful.
  describe '.default_mvi_open_timeout' do
    context 'when Settings.mvi.open_timeout is not set' do
      it 'should use the default' do
        expect(MVI::Configuration::OPEN_TIMEOUT).to eq(2)
      end
    end
  end

  describe '.default_mvi_timeout' do
    context 'when Settings.mvi.timeout is not set' do
      it 'should use the default' do
        expect(MVI::Configuration::TIMEOUT).to eq(10)
      end
    end
  end
end
