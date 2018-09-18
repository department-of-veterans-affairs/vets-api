# frozen_string_literal: true

module SAML
  # This module is responsible for providing the URLs for the various SSO and SLO endpoints
  module URLService
    # converts from symbols to strings
    SUCCESS_RELAY_KEYS = Settings.saml.relays&.keys&.map { |k| k.to_s }

    # SSO URLS
    def mhv_url(relay_state)
      build_sso_url(authn_context: 'myhealthevet', connect: 'myhealthevet', relay_state: relay_state)
    end

    def dslogon_url(relay_state)
      build_sso_url(authn_context: 'dslogon', connect: 'dslogon', relay_state: relay_state)
    end

    def idme_loa1_url(relay_state)
      build_sso_url(relay_state: relay_state)
    end

    def idme_loa3_url(current_user, relay_state)
      build_sso_url(
        authn_context: LOA::MAPPING.invert[3], connect: current_user.authn_context, relay_state: relay_state
      )
    end

    def mfa_url(current_user, relay_state)
      policy = current_user.authn_context
      authn_context = policy.present? ? "#{policy}_multifactor" : 'multifactor'
      build_sso_url(authn_context: authn_context, connect: policy, relay_state: relay_state)
    end

    # This is the internal vets-api url that first gets invoked, it should redirect without authentication
    # when this url gets invoked, the session should be destroyed, before the callback returns
    def logout_url(session, relay_state)
      token = Base64.urlsafe_encode64(session.token)
      Rails.application.routes.url_helpers.logout_v0_sessions_url(
        success_relay: relay_state.relay_enum, session: token
      )
    end

    # SLO URLS
    def slo_url(session, relay_state)
      build_slo_url(session, relay_state)
    end

    private

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # nil authn_context and nil connect will always default to idme level 1
    # authn_context is the policy, connect represents the ID.me specific flow.
    def build_sso_url(authn_context: LOA::MAPPING.invert[1], connect: nil, session: nil, relay_state: nil)
      url_settings = url_settings(authn_context: authn_context, name_identifier_value: session&.uuid)
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      connect_param = "&connect=#{connect}"
      link = saml_auth_request.create(url_settings, RelayState: relay_state.login_url)
      connect.present? ? link + connect_param : link
    end

    # Builds the url to trigger SLO, caching the request
    def build_slo_url(session, relay_state)
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      Rails.logger.info "New SP SLO for userid '#{session.uuid}'"

      url_settings = url_settings(name_identifier_value: session.uuid)
      # cache the request for session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
      logout_request.create(url_settings, RelayState: relay_state.logout_url)
    end

    def url_settings(options)
      saml_settings(options)
    end
  end
end
