# frozen_string_literal: true

require 'rails_helper'
require 'oidc/key_service'

RSpec.describe OIDC::KeyService do
  describe '::fetch_keys' do
    it 'pulls keys from the specified metadata endpoint' do
      with_settings(
        Settings.oidc,
        auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
        issuer: 'https://example.com/oauth2/default',
        base_api_url: 'https://example.com/api/v1/',
        base_api_token: 'token'
      ) do
        VCR.use_cassette('okta/keys') do
          out = described_class.fetch_keys
          expect(out['keys'].count).to eq(1)
        end
      end
    end
  end

  describe '::get_key' do
    after do
      described_class.reset!
    end

    it 'returns the current key if it already exists' do
      described_class.instance_variable_set(:@current_keys, {'key' => 'key'})
      expect(described_class.get_key('key')).to eq 'key'
    end

    it 'avoids upstream requests for repeated bad kids' do
      expect(described_class).to receive(:refresh).once
      described_class.get_key('bad kid')
      described_class.get_key('bad kid')
    end

    it 'refreshes a bad kid after one minute' do
      expect(described_class).to receive(:refresh).twice
      described_class.get_key('bad kid')
      Timecop.travel(Time.zone.now + 61)
      described_class.get_key('bad kid')
      Timecop.return
    end

    context 'with okta api recordings' do
      around do |example|
        with_settings(
          Settings.oidc,
          auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
          issuer: 'https://example.com/oauth2/default',
          base_api_url: 'https://example.com/',
          base_api_token: 'token'
        ) do
          VCR.use_cassette('okta/keys') do
            example.run
          end
        end
      end

      it 'downloads new keys if it does not exist' do
        key = described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU')
        expect(key).to be_a(OpenSSL::PKey::RSA)
      end

    end
  end
end
