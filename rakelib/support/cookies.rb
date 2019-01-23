# frozen_string_literal: true

class Cookies
  def self.bake(session)
    user = User.find(session.uuid)
    api_session = encrypt_api_session_cookie(session)
    sso_session = encrypt_sso_cookie(user, session)
    "Cookie: api_session=#{api_session}; #{Settings.sso.cookie_name}=#{sso_session}"
  end

  def self.encrypt_api_session_cookie(session)
    salt = Rails.application.config.action_dispatch.encrypted_cookie_salt
    signed_salt = Rails.application.config.action_dispatch.encrypted_signed_cookie_salt
    key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base, iterations: 1000)
    secret = key_generator.generate_key(salt)[0, ActiveSupport::MessageEncryptor.key_len]
    sign_secret = key_generator.generate_key(signed_salt)
    encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
    encryptor.encrypt_and_sign(session.to_hash.reverse_merge(session_id: SecureRandom.hex(32)))
  end

  def self.encrypt_sso_cookie(user, session)
    content = {
      'patientIcn' => (user.mhv_icn || user.icn),
      'mhvCorrelationId' => user.mhv_correlation_id,
      'signIn' => user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
      'credential_used' => 'LOAD TESTING',
      'expirationTime' => session.ttl_in_time.iso8601(0)
    }
    SSOEncryptor.encrypt(ActiveSupport::JSON.encode(content))
  end
end
