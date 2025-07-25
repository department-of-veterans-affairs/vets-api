# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'rails_helper'
require 'ssoe/configuration'

RSpec.describe SSOe::Configuration do
  subject(:config) { described_class.send(:new) }

  let(:base_url) { 'https://int.services.eauth.va.gov:9303/psim_webservice/dev/IdMSSOeWebService' }
  let(:cert_path) { 'spec/fixtures/certs/vetsgov-localhost.crt' }
  let(:key_path) { 'spec/fixtures/certs/vetsgov-localhost.key' }

  let(:cert_obj) { OpenSSL::X509::Certificate.new(File.read(cert_path)) }
  let(:key_obj) { OpenSSL::PKey::RSA.new(File.read(key_path)) }

  let(:faraday_connection) { instance_double(Faraday::Connection) }

  # rubocop:disable RSpec/SubjectStub
  before do
    allow(config).to receive_messages(ssl_cert: cert_obj, ssl_key: key_obj)
  end
  # rubocop:enable RSpec/SubjectStub

  describe '#connection' do
    it 'creates a Faraday connection with correct SSL options' do
      expect(Faraday).to receive(:new)
        .with(base_url, hash_including(
                          ssl: hash_including(
                            client_cert: cert_obj,
                            client_key: key_obj
                          )
                        )).and_return(faraday_connection)

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
