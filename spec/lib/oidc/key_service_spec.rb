# frozen_string_literal: true

require 'rails_helper'
require 'oidc/key_service'

RSpec.describe OIDC::KeyService do
  let(:expected_iss) { 'https://example.com/oauth2/default' }

  describe '::get_key' do
    after do
      described_class.reset!
    end

    it 'returns the current key if it already exists' do
      described_class.instance_variable_set(:@current_keys, 'key' => 'key')
      expect(described_class.get_key('key', anything)).to eq 'key'
    end

    it 'avoids upstream requests for repeated bad kids' do
      expect(described_class).to receive(:refresh).once
      described_class.get_key('bad kid', anything)
      described_class.get_key('bad kid', anything)
    end

    it 'refreshes a bad kid after one minute' do
      expect(described_class).to receive(:refresh).twice
      described_class.get_key('bad kid', anything)
      Timecop.travel(Time.zone.now + 61)
      described_class.get_key('bad kid', anything)
      Timecop.return
    end

    it 'limits the size of the bad kid cache' do
      expect(described_class).to receive(:refresh).exactly(1002).times

      # Add a kid with a timestamp in the past
      Timecop.travel(Time.zone.now - 30)
      described_class.get_key('oldest key', anything)
      Timecop.return

      # Fill up the kid cache so the first key we've added is evicted
      1000.times do |x|
        described_class.get_key(x, anything)
      end

      # Since this key was evicted, this call will trigger the 1002nd refresh
      described_class.get_key('oldest key', anything)
    end

    context 'with okta api recordings' do
      around do |example|
        with_settings(
          Settings.oidc,
          auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
          issuer: 'https://example.com/oauth2/default',
          issuer_prefix: 'https://example.com/oauth2',
          base_api_url: 'https://example.com/',
          base_api_token: 'token'
        ) do
          with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
            VCR.use_cassette('okta/keys') do
              example.run
            end
          end
        end
      end

      it 'downloads new keys if it does not exist' do
        key = described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU', 'https://example.com/oauth2/default')
        expect(key).to be_a(OpenSSL::PKey::RSA)
      end

      it 'invalid prefix' do
        with_settings(Settings.oidc.issuers.first, prefix: 'https://example.bad.com/') do
          expect do
            described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU', 'https://example.com/oauth2/default')
          end.to raise_error { |error|
            expect(error).to be_a(Common::Exceptions::OpenIdServiceError)
            expect(error.code).to eq 401
            expect(error.status).to eq 401
          }
        end
      end

      it 'invalid proxy' do
        with_settings(Settings.oidc.issuers.first, proxy: 'https://example.bad.com/') do
          expect do
            described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU', 'https://example.com/oauth2/default')
          end.to raise_error { |error|
            expect(error).to be_a(Common::Exceptions::OpenIdServiceError)
            expect(error.code).to eq 404
            expect(error.status).to eq 404
          }
        end
      end
    end

    context 'with okta api recordings no jwks' do
      around do |example|
        with_settings(
          Settings.oidc,
          auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
          issuer: 'https://example.com/oauth2/default',
          issuer_prefix: 'https://example.com/oauth2',
          base_api_url: 'https://example.com/',
          base_api_token: 'token'
        ) do
          with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
            VCR.use_cassette('okta/metadata-no-jwks') do
              example.run
            end
          end
        end
      end

      it 'no jwks' do
        expect do
          described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU', 'https://example.com/oauth2/default')
        end.to raise_error { |error|
          expect(error).to be_a(Common::Exceptions::OpenIdServiceError)
          expect(error.code).to eq 404
          expect(error.status).to eq 404
        }
      end
    end

    context 'with okta api recordings bad jwks' do
      around do |example|
        with_settings(
          Settings.oidc,
          auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/oauth-authorization-server',
          issuer: 'https://example.com/oauth2/default',
          issuer_prefix: 'https://example.com/oauth2',
          base_api_url: 'https://example.com/',
          base_api_token: 'token'
        ) do
          with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
            VCR.use_cassette('okta/metadata-bad') do
              example.run
            end
          end
        end
      end

      it 'bad jwks' do
        expect do
          described_class.get_key('1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU', 'https://example.com/oauth2/default')
        end.to raise_error { |error|
          expect(error).to be_a(Common::Exceptions::OpenIdServiceError)
          expect(error.code).to eq 404
          expect(error.status).to eq 404
        }
      end
    end
  end
end
