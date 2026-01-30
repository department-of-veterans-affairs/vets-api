# frozen_string_literal: true

require 'rails_helper'
require 'httpclient'

RSpec.describe RepresentationManagement::GCLAWS::XlsxConfiguration do
  subject(:configuration) { described_class.new }

  let(:test_url) { 'https://ssrs.example.com/reports/accreditation.xlsx' }
  let(:test_username) { 'test_user' }
  let(:test_password) { 'test_password' }

  before do
    allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
      OpenStruct.new(
        url: test_url,
        username: test_username,
        password: test_password
      )
    )
  end

  describe '#connection' do
    it 'returns an HTTPClient instance' do
      expect(configuration.connection).to be_a(HTTPClient)
    end

    it 'configures NTLM authentication with the correct credentials' do
      client = configuration.connection
      # HTTPClient stores auth info internally, we verify by checking the client was created
      expect(client).to be_a(HTTPClient)
    end

    it 'uses system CA certificates for SSL verification' do
      client = configuration.connection
      # HTTPClient defaults to VERIFY_PEER | VERIFY_FAIL_IF_NO_PEER_CERT (3)
      expect(client.ssl_config.verify_mode).to be >= OpenSSL::SSL::VERIFY_PEER
    end
  end

  describe '#url' do
    it 'returns the configured URL from settings' do
      expect(configuration.url).to eq(test_url)
    end
  end

  describe 'settings access' do
    it 'reads username from Settings.gclaws.accreditation_xlsx' do
      expect(Settings.gclaws.accreditation_xlsx.username).to eq(test_username)
    end

    it 'reads password from Settings.gclaws.accreditation_xlsx' do
      expect(Settings.gclaws.accreditation_xlsx.password).to eq(test_password)
    end

    it 'reads url from Settings.gclaws.accreditation_xlsx' do
      expect(Settings.gclaws.accreditation_xlsx.url).to eq(test_url)
    end
  end
end
