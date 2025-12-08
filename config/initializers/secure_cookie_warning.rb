# frozen_string_literal: true

# Logs an error when secure session cookies would not be committed due to SSL mismatch.
#
# Background:
# - rack-session checks security_matches? before committing cookies
# - If secure: true but request.ssl? returns false, cookies are NOT committed
# - This causes users to appear unauthenticated after login
#
# This middleware detects this condition and logs an error to help diagnose
# authentication failures caused by proxy header misconfiguration.
#
# See: https://github.com/department-of-veterans-affairs/vets-api/pull/25227
class SecureCookieWarning
  def initialize(app)
    @app = app
    @enabled = IdentitySettings.session_cookie.warn_on_ssl_mismatch
  end

  def call(env)
    status, headers, body = @app.call(env)

    # Only check if explicitly enabled via config
    # Disabled by default to avoid overhead in production
    if @enabled
      # Check scheme without creating a Rack::Request object
      # This mirrors Rack::Request#ssl? logic but avoids object allocation
      scheme = env['HTTP_X_FORWARDED_PROTO'] || env['HTTP_X_FORWARDED_SCHEME'] || env['rack.url_scheme']
      is_ssl = scheme&.downcase == 'https'

      unless is_ssl
        Rails.logger.error(
          '[SecureCookieWarning] Secure session cookies will NOT be saved! ' \
          "X-Forwarded-Proto=#{env['HTTP_X_FORWARDED_PROTO'].inspect}, " \
          "X-Forwarded-Scheme=#{env['HTTP_X_FORWARDED_SCHEME'].inspect}, " \
          "rack.url_scheme=#{env['rack.url_scheme'].inspect}"
        )
      end
    end

    [status, headers, body]
  end
end

# Insert after session middleware so we can check the final state
Rails.application.config.middleware.insert_after(
  ActionDispatch::Session::CookieStore,
  SecureCookieWarning
)
