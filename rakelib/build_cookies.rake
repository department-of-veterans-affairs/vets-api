# frozen_string_literal: true

namespace :build_cookies do
  desc 'returns cookie header for authentication'
  task headers: [:token] => [:environment] do |_, args|
    raise 'No token provided' unless args[:token]
    session = Session.find(token)
    raise 'No session available for token' unless session.is_a?(Session)
    user = User.find(session.uuid)

    sso_cookie_data = rake_set_sso_cookie(user, session)
    session_cookie_data = rake_set_session_cookie(session)

    # figure out how cookie jar works for cookies and session
    # figure out how rack, builds cookie header based off of cookie jar
    # then return the headers as the output for this rake task
end

# Sets a cookie used by MHV for SSO
def rake_set_sso_cookie(user, session)
  encryptor = SSOEncryptor
  encrypted_value = encryptor.encrypt(ActiveSupport::JSON.encode(sso_cookie_content(user, session)))

  # figure out how cookies method in controller works, and refence it or duplicate code here.
  cookies[Settings.sso.cookie_name] = {
    value: encrypted_value,
    expires: nil, # NOTE: we track expiration as an attribute in "value." nil here means kill cookie on browser close.
    secure: Settings.sso.cookie_secure,
    httponly: true,
    domain: Settings.sso.cookie_domain
  }
end

def rake_set_session_cookie(session_object)
  # figure out how session method in controller works, and reference it or duplicate code here.
  session_object.to_hash.each { |k, v| session[k] = v }
end

# The contents of MHV SSO Cookie with specifications found here:
# https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SSO/CookieSpecs-20180906.docx
def rake_sso_cookie_content(user, session)
  return nil if user.blank?
  {
    'patientIcn' => (user.mhv_icn || user.icn),
    'mhvCorrelationId' => user.mhv_correlation_id,
    'signIn' => user.identity.sign_in.deep_transform_keys { |key| key.to_s.camelize(:lower) },
    'credential_used' => sso_cookie_sign_credential_used,
    'expirationTime' => session.ttl_in_time.iso8601(0)
  }
end
