# frozen_string_literal: true

require 'rails_helper'
require 'mpi/configuration'

describe MPI::Configuration do
  describe '.ssl_options' do
    context 'when there are no SSL options' do
      before do
        allow(MPI::Configuration.instance).to receive_messages(ssl_cert: nil, ssl_key: nil)
      end

      it 'returns nil' do
        allow(MPI::Configuration.instance).to receive_messages(ssl_cert: nil, ssl_key: nil)
        expect(MPI::Configuration.instance.ssl_options).to be_nil
      end
    end

    context 'when there are SSL options' do
      let(:cert) { instance_double(OpenSSL::X509::Certificate) }
      let(:key) { instance_double(OpenSSL::PKey::RSA) }

      before do
        allow(MPI::Configuration.instance).to receive(:ssl_cert) { cert }
        allow(MPI::Configuration.instance).to receive(:ssl_key) { key }
      end

      it 'returns the wsdl, cert and key paths' do
        expect(MPI::Configuration.instance.ssl_options).to eq(
          client_cert: cert,
          client_key: key
        )
      end
    end
  end

  describe '.open_timeout' do
    context 'when IdentitySettings.mvi.open_timeout is set' do
      it 'uses the setting' do
        expect(MPI::Configuration.instance.open_timeout).to eq(15)
      end
    end
  end

  describe '.read_timeout' do
    context 'when IdentitySettings.mvi.timeout is set' do
      it 'uses the setting' do
        expect(MPI::Configuration.instance.read_timeout).to eq(30)
      end
    end
  end
end
