# frozen_string_literal: true
require 'rails_helper'
require 'mvi/service'

describe MVI::Configuration do
  describe '.ssl_options' do
    context 'when there are no SSL options' do
      before do
        stub_const('MVI::Configuration::SSL_CERT', nil)
        stub_const('MVI::Configuration::SSL_KEY', nil)
      end

      it 'should return nil' do
        stub_const('MVI::Configuration::SSL_CERT', nil)
        stub_const('MVI::Configuration::SSL_KEY', nil)
        expect(MVI::Configuration.instance.ssl_options).to be_nil
      end
    end
    context 'when there are SSL options' do
      let(:cert) { instance_double('OpenSSL::X509::Certificate') }
      let(:key) { instance_double('OpenSSL::PKey::RSA') }

      before do
        stub_const('MVI::Configuration::SSL_CERT', cert)
        stub_const('MVI::Configuration::SSL_KEY', key)
      end

      it 'should return the wsdl, cert and key paths' do
        expect(MVI::Configuration.instance.ssl_options).to eq(
          client_cert: cert,
          client_key: key
        )
      end
    end
  end
end
