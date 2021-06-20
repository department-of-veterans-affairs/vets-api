# frozen_string_literal: true

require 'rails_helper'
require './rakelib/support/cookies.rb'

describe Cookies do
  subject { described_class.new(session) }

  let(:user) { create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

  describe '#api_session_header' do
    # much of this code comes from here: https://gist.github.com/wildjcrt/6359713fa770d277927051fdeb30ebbf
    def decrypt_session_cookie(cookie)
      config = Rails.application.config
      encrypted_cookie_cipher = config.action_dispatch.encrypted_cookie_cipher || 'aes-256-gcm'

      key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base, iterations: 1000)
      key_len = ActiveSupport::MessageEncryptor.key_len(encrypted_cookie_cipher)
      secret = key_generator.generate_key(config.action_dispatch.authenticated_encrypted_cookie_salt, key_len)
      # ActiveSupport::MessageEncryptor defaults to `Marshal` if no serializer is provided
      # Make sure this matches the vets-api config: Rails.application.config.action_dispatch.cookies_serializer
      encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: encrypted_cookie_cipher, serializer: nil)

      encryptor.decrypt_and_verify(CGI.unescape(cookie), purpose: 'cookie.api_session')
    end

    let(:api_session_header) { subject.api_session_header }
    let(:decrypted_api_session_header) do
      decrypt_session_cookie(api_session_header.match(/^api_session=(.*)$/).captures.first)
    end

    it 'includes the uuid' do
      expect(decrypted_api_session_header['uuid']).to eq(session.uuid)
    end

    it 'includes the token' do
      expect(decrypted_api_session_header['token']).to eq(session.token)
    end

    it 'includes the created_at date' do
      expect(decrypted_api_session_header['created_at']).to eq(session.created_at)
    end
  end

  describe '#sso_session_header' do
    def decrypt_sso_cookie(cookie)
      JSON.parse(SSOEncryptor.decrypt(cookie))
    end

    let(:sso_header) { subject.sso_session_header }
    let(:decrypted_sso_header) do
      decrypt_sso_cookie(sso_header.match(/^#{Settings.sso.cookie_name}=(.*)$/).captures.first)
    end

    it 'was encrypted correctly' do
      expect(decrypted_sso_header).to eq(
        'patientIcn' => user.icn,
        'mhvCorrelationId' => user.mhv_correlation_id,
        'signIn' => { 'serviceName' => 'idme' },
        'credential_used' => 'LOAD TESTING',
        'expirationTime' => session.ttl_in_time.iso8601(0)
      )
    end
  end
end
