# frozen_string_literal: true

require 'rails/session_cookie'

class Cookies
  def initialize(session)
    @session = session
    @user = User.find(session.uuid)
  end

  def to_header
    "#{api_session_header}; #{sso_session_header}"
  end

  def api_session_header
    session_options = { key: 'api_session' }
    session_data = @session.to_hash.reverse_merge(session_id: SecureRandom.hex(32))
    raw_cookie = Rails::SessionCookie::App.new(session_data, session_options).session_cookie

    raw_cookie.chomp("\; path=\/\; HttpOnly")
  end

  def sso_session_header
    "#{Settings.sso.cookie_name}=#{encrypt_sso_cookie(@session, @user)}"
  end

  private

  def encrypt_sso_cookie(session, user)
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
