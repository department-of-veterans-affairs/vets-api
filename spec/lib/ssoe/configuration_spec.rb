# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'rails_helper'
require 'ssoe/configuration'

RSpec.describe SSOe::Configuration do
  subject(:config) { described_class.send(:new) }

  let!(:cert) do
    Tempfile.new('cert').tap do |file|
      cert = OpenSSL::X509::Certificate.new
      cert.subject = OpenSSL::X509::Name.parse('/CN=test')
      cert.version = 2
      cert.serial = 1
      cert.not_before = Time.zone.now
      cert.not_after = cert.not_before + 3600
      key = OpenSSL::PKey::RSA.new(2048)
      cert.public_key = key.public_key
      cert.sign(key, OpenSSL::Digest.new('SHA256'))
      file.write(cert.to_pem)
      file.rewind
    end
  end

  let!(:key) do
    Tempfile.new('key').tap do |file|
      file.write(OpenSSL::PKey::RSA.new(2048).to_pem)
      file.rewind
    end
  end

  before do
    cert_path = cert.path
    key_path = key.path

    stub_const('IdentitySettings', Class.new do
      define_singleton_method(:ssoe_get_traits) do
        OpenStruct.new(
          client_cert_path: cert_path,
          client_key_path: key_path,
          url: 'https://fake-url/'
        )
      end
    end)
  end

  describe '#base_path' do
    {
      'development' => 'https://int.services.eauth.va.gov:9303/psim_webservice/dev/IdMSSOeWebService',
      'staging' => 'https://sqa.services.eauth.va.gov:9303/psim_webservice/IdMSSOeWebService',
      'production' => 'https://services.eauth.va.gov:9303/psim_webservice/IdMSSOeWebService'
    }.each do |env, expected_url|
      context "when environment is #{env}" do
        let(:ssoe_get_traits_double) { double(url: expected_url) }

        before do
          allow(IdentitySettings).to receive(:ssoe_get_traits).and_return(ssoe_get_traits_double)
        end

        it "returns the correct URL for #{env}" do
          expect(config.send(:base_path)).to eq(expected_url)
        end
      end
    end
  end

  describe '#ssl_options' do
    context 'when cert and key are valid' do
      it 'returns OpenSSL objects for client_cert and client_key' do
        ssl_opts = config.send(:ssl_options)
        expect(ssl_opts).to be_a(Hash)
        expect(ssl_opts[:client_cert]).to be_a(OpenSSL::X509::Certificate)
        expect(ssl_opts[:client_key]).to be_a(OpenSSL::PKey::RSA)
      end

      context 'when cert and key are not valid' do
        it 'raises an error if cert or key files are missing' do
          config_class = Class.new(SSOe::Configuration) do
            def ssl_cert = nil
            def ssl_key = nil
          end

          missing_config = config_class.send(:new)

          expect do
            missing_config.send(:ssl_options)
          end.to raise_error('SSL options not defined')
        end

        it 'logs and raises OpenSSL error' do
          config_class = Class.new(SSOe::Configuration) do
            def ssl_cert
              raise OpenSSL::OpenSSLError, 'bad cert'
            end

            def ssl_key
              OpenSSL::PKey::RSA.new(2048)
            end
          end

          config = config_class.send(:new)
          expect(Rails.logger).to receive(:error).with(/\[SSOe::Configuration\] SSL error: bad cert/)

          expect do
            config.send(:ssl_options)
          end.to raise_error(OpenSSL::OpenSSLError, 'bad cert')
        end
      end
    end
  end

  describe '#connection' do
    it 'creates a Faraday connection' do
      connection = config.connection
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq(config.send(:base_path))
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
