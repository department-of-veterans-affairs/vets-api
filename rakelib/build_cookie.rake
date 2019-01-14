# frozen_string_literal: true
require 'net/http'
require 'uri'

namespace :build_cookie do
  RAKE_SESSION_COOKIE_KEY = 'api_session'
  RAKE_SESSION_COOKIE_DOMAIN = Settings.hostname
  RAKE_SSO_COOKIE_KEY = Settings.sso.cookie_name
  RAKE_SSO_COOKIE_DOMAIN = Settings.sso.cookie_domain
  RAKE_COOKIE_OPTIONS = { expires: nil, secure: true, http_only: true }.freeze
  RAKE_VERIFY_HEADERS = true

  # rubocop:disable Metrics/LineLength
  desc 'returns cookie header for authentication'
  task :headers, [:token] => [:environment] do |_, args|
    raise 'No token provided' unless args[:token]
    session = Session.find(args[:token])
    raise 'No session available for token' unless session.is_a?(Session)
    user = User.find(session.uuid)

    session_cookie_options = RAKE_COOKIE_OPTIONS.merge(value: rake_session_cookie(session), domain: RAKE_SESSION_COOKIE_DOMAIN)
    sso_cookie_options = RAKE_COOKIE_OPTIONS.merge(value: rake_sso_cookie(user, session), domain: RAKE_SSO_COOKIE_DOMAIN)

    header = {}
    Rack::Utils.set_cookie_header!(header, RAKE_SESSION_COOKIE_KEY, session_cookie_options)
    #Rack::Utils.set_cookie_header!(header, RAKE_SSO_COOKIE_KEY, sso_cookie_options)
    verify_header(header) if RAKE_VERIFY_HEADERS
    puts header
  end

  def verify_header(headers)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get "/", nil
  end

  # SESSION COOKIE METHODS
  def rake_session_cookie(session)
    content = session.to_hash.reverse_merge(session_id: SecureRandom.hex(32))
    key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base, iterations: 1000)
    secret = key_generator.generate_key(Rails.application.config.action_dispatch.encrypted_cookie_salt)
    sign_secret = key_generator.generate_key(Rails.application.config.action_dispatch.encrypted_signed_cookie_salt)
    encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
    encryptor.encrypt_and_sign(ActiveSupport::JSON.encode(content))
  end
  # rubocop:enable Metrics/LineLength

  # SSO COOKIE METHODS
  def rake_sso_cookie(user, session)
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
