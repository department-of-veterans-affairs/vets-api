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
          expect(config.base_path).to eq(expected_url)
        end
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
