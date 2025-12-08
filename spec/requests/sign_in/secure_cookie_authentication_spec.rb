# frozen_string_literal: true

require 'rails_helper'

# Regression test for Rack 3 upgrade breaking authentication.
# See: https://github.com/department-of-veterans-affairs/vets-api/pull/25227
#
# Root cause:
# - Traefik sets X-Forwarded-Proto: http (internal connection)
# - nginx sets X-Forwarded-Scheme: https (original client protocol)
# - Rack 2: Checked Scheme first -> found 'https' -> ssl? = true ✓
# - Rack 3: Checks Proto first -> finds 'http' -> ssl? = false ✗
#
# When ssl? returns false with secure: true cookies, rack-session's
# security_matches? returns false and session cookies are NOT committed.
# This causes users to appear unauthenticated after login.
RSpec.describe 'Rack SSL detection with production proxy headers', type: :request do
  it 'detects SSL when X-Forwarded-Proto=http and X-Forwarded-Scheme=https' do
    # Production proxy chain sends both headers with conflicting values.
    # For auth to work, ssl? must return true so secure cookies are committed.
    env = Rack::MockRequest.env_for(
      '/test',
      method: 'GET',
      'HTTP_X_FORWARDED_PROTO' => 'http',
      'HTTP_X_FORWARDED_SCHEME' => 'https'
    )
    request = Rack::Request.new(env)

    expect(request.ssl?).to be(true), <<~MSG
      CRITICAL: Rack::Request#ssl? returned false with production proxy headers!

      Headers received:
      - X-Forwarded-Proto: http (from Traefik - internal connection)
      - X-Forwarded-Scheme: https (from nginx - original client protocol)

      This breaks authentication because:
      1. rack-session checks security_matches? before committing cookies
      2. security_matches? returns false when ssl? is false and secure: true
      3. Session cookies are NOT saved
      4. User appears unauthenticated on next request

      Rack 3 changed x_forwarded_proto_priority from [:scheme, :proto] to [:proto, :scheme]
      This means X-Forwarded-Proto: http is checked first, returning 'http' immediately.

      FIX: Add config/initializers/rack_forwarded_priority.rb:
        Rack::Request.x_forwarded_proto_priority = [:scheme, :proto]

      OR update nginx to send X-Forwarded-Proto: https
    MSG
  end
end
