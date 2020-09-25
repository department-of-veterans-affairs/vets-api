module SSO
    class SAMLCookie
        def self.from(session_object, current_user, sso_logging_info, cookies)
          return unless Settings.sso.cookie_enabled &&
                        session_object.present? &&
                        # if the user logged in via SSOe, there is no benefit from
                        # creating a MHV SSO shared cookie
                        !current_user&.authenticated_by_ssoe

          Rails.logger.info('SSO: ApplicationController#set_sso_cookie!', sso_logging_info)

          cookies[Settings.sso.saml_cookie_name] = {
            value: (current_user.present? ? cookie_content : nil),
            expires: nil, # NOTE: we track expiration as an attribute in "value." nil here means kill cookie on browser close.
            secure: Settings.sso.cookie_secure,
            httponly: true,
            domain: Settings.sso.cookie_domain
          }
        end

        def self.cookie_content
          {
            'timestamp' => Time.now.iso8601,
            'transaction_id' => '',
            'saml_request_id' => '',
            'saml_request_query_params' => ''
          }
        end
    end
end
