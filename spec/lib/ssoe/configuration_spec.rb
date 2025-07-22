# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'rails_helper'
require 'ssoe/configuration'

RSpec.describe SSOe::Configuration do
  subject(:config) { described_class.send(:new) }

  let(:config_with_keys) do
    Class.new(SSOe::Configuration) do
      def ssl_cert = 'fake_cert'
      def ssl_key = 'fake_key'
    end.send(:new)
  end

  let(:config_without_keys) do
    Class.new(SSOe::Configuration) do
      def ssl_cert = nil
      def ssl_key = nil
    end.send(:new)
  end

  describe '#base_path' do
    context 'when environment is staging' do
      before { allow(Settings).to receive(:vsp_environment).and_return('staging') }

      it 'returns staging URL' do
        expect(config.base_path).to eq('https://sqa.services.eauth.va.gov:9303/psim_webservice/IdMSSOeWebService')
      end
    end

    context 'when environment is not staging or production' do
      before { allow(Settings).to receive(:vsp_environment).and_return('development') }

      it 'returns dev URL' do
        expect(config.base_path).to eq('https://int.services.eauth.va.gov:9303/psim_webservice/dev/IdMSSOeWebService')
      end
    end
  end

  describe '#ssl_options' do
    it 'returns a hash with client_cert and client_key if present' do
      expect(config_with_keys.ssl_options).to eq(
        client_cert: 'fake_cert',
        client_key: 'fake_key'
      )
    end

    it 'returns nil if cert or key is missing' do
      expect(config_without_keys.ssl_options).to be_nil
    end
  end

  describe '#connection' do
    it 'creates a Faraday connection' do
      connection = config.connection
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq(config.base_path)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
