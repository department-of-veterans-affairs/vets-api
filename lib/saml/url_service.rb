# frozen_string_literal: true

module SAML
  # This module is responsible for providing the URLs for the various SSO and SLO endpoints
  module URLService
    # SSO URLS
    def mhv_url(url_settings)
      build_sso_url(authn_context: 'myhealthevet')
    end

    def dslogon_url(url_settings)
      build_sso_url(authn_context: 'dslogon')
    end

    def idme_loa1_url(url_settings)
      build_sso_url
    end

    def idme_loa3_url(current_user, url_settings)
      policy = current_user.authn_context
      authn_context = policy.present? ? "#{policy}_loa3" : LOA::MAPPING.invert[3]
      build_sso_url(authn_context: authn_context)
    end

    def mfa_url(current_user, url_settings)
      policy = current_user.authn_context
      authn_context = policy.present? ? "#{policy}_multifactor" : 'multifactor'
      build_sso_url(authn_context: authn_context)
    end

    # This is the internal vets-api url that first gets invoked, it should redirect without authentication
    # when this url gets invoked, the session should be destroyed, before the callback returns
    def logout_url(session, url_settings)
      token = Base64.urlsafe_encode64(session.token)
      Rails.application.routes.url_helpers.logout_v0_sessions_url(session: token)
    end

    # SLO URLS
    def slo_url(session, url_settings)
      build_slo_url(session, relay_state)
    end

    private

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # nil authn_context and nil connect will always default to idme level 1
    # authn_context is the policy, connect represents the ID.me specific flow.
    def build_sso_url(url_settings, authn_context: LOA::MAPPING.invert[1], session: nil)
      url_settings = url_settings(authn_context: authn_context, name_identifier_value: session&.uuid)
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      saml_auth_request.create(url_settings)
    end

    # Builds the url to trigger SLO, caching the request
    def build_slo_url(url_settings, session)
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      Rails.logger.info "New SP SLO for userid '#{session.uuid}'"

      url_settings.name_identifier_value = session.uuid
      # cache the request for session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
      logout_request.create(url_settings)
    end
  end
end
