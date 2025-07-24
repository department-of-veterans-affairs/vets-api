# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'rails_helper'
require 'ssoe/configuration'

RSpec.describe SSOe::Configuration do
  subject(:config) { described_class.send(:new) }

  let(:base_url) { 'https://api.example.com/soap' }
  let(:cert_path) { '/tmp/client.pem' }
  let(:key_path) { '/tmp/client.key' }

  let(:cert_data) { 'PEM-DATA' }
  let(:key_data) { 'KEY-DATA' }
  let(:cert_obj) { instance_double(OpenSSL::X509::Certificate) }
  let(:key_obj) { instance_double(OpenSSL::PKey::RSA) }

  let(:faraday_connection) { instance_double(Faraday::Connection) }

  before do
    allow(IdentitySettings.ssoe_get_traits).to receive_messages(url: base_url, client_cert_path: cert_path,
                                                                client_key_path: key_path)

    allow(File).to receive(:exist?).with(cert_path).and_return(true)
    allow(File).to receive(:exist?).with(key_path).and_return(true)
    allow(File).to receive(:read).with(cert_path).and_return(cert_data)
    allow(File).to receive(:read).with(key_path).and_return(key_data)

    allow(OpenSSL::X509::Certificate).to receive(:new).with(cert_data).and_return(cert_obj)
    allow(OpenSSL::PKey::RSA).to receive(:new).with(key_data).and_return(key_obj)
  end

  describe '#connection' do
    it 'creates a Faraday connection with correct SSL options' do
      expect(Faraday).to receive(:new)
        .with(base_url, hash_including(ssl: { client_cert: cert_obj, client_key: key_obj }))
        .and_return(faraday_connection)

      connection = config.connection
      expect(connection).to be(faraday_connection)
    end
  end

  describe '#service_name' do
    it 'returns "SSOe"' do
      expect(config.service_name).to eq('SSOe')
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
