# frozen_string_literal: true

require 'rails_helper'
require 'oidc/key_service'

RSpec.describe OIDC::KeyService do
  describe '::fetch_keys' do
    it 'should pull keys from the specified metadata endpoint' do
      with_settings(
        Settings.oidc,
        auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
        issuer: 'https://example.com/oauth2/default',
        profile_api_url: 'https://example.com/api/v1/users/',
        profile_api_token: 'token'
      ) do
        VCR.use_cassette('okta/keys') do
          out = described_class.fetch_keys
          expect(out['keys'].count).to eq(1)
        end
      end
    end
  end

  describe '::get_key' do
    after(:each) do
      described_class.instance_variable_set(:@current_key, {})
    end

    it 'should return the current key if it already exists' do
      described_class.current_keys['key'] = 'key'
      expect(described_class.get_key('key')).to eq 'key'
    end

    it 'should download new keys if it does not exist' do
      with_settings(
        Settings.oidc,
        auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
        issuer: 'https://example.com/oauth2/default',
        profile_api_url: 'https://example.com/api/v1/users/',
        profile_api_token: 'token'
      ) do
        VCR.use_cassette('okta/keys') do
          key = described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU')
          expect(key).to be_a(OpenSSL::PKey::RSA)
        end
      end
    end
  end
end
