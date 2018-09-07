# frozen_string_literal: true

module SAML
  # This module is responsible for providing the URLs for the various SSO and SLO endpoints
  module URLService
    # SSO URLS
    def mhv_url(success_relay: nil)
      build_sso_url(authn_context: 'myhealthevet', connect: 'myhealthevet', success_relay: success_relay)
    end

    def dslogon_url(success_relay: nil)
      build_sso_url(authn_context: 'dslogon', connect: 'dslogon', success_relay: success_relay)
    end

    def idme_loa1_url(success_relay: nil)
      build_sso_url(success_relay: success_relay)
    end

    def idme_loa3_url(current_user, success_relay: nil)
      build_sso_url(
        authn_context: LOA::MAPPING.invert[3], connect: current_user.authn_context, success_relay: success_relay
      )
    end

    def mfa_url(current_user, success_relay: nil)
      policy = current_user.authn_context
      authn_context = policy.present? ? "#{policy}_multifactor" : 'multifactor'
      build_sso_url(authn_context: authn_context, connect: policy, success_relay: success_relay)
    end

    # SLO URLS
    def slo_url(session)
      build_slo_url(session)
    end

    private

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # nil authn_context and nil connect will always default to idme level 1
    # authn_context is the policy, connect represents the ID.me specific flow.
    def build_sso_url(authn_context: LOA::MAPPING.invert[1], connect: nil, session: nil, success_relay: nil)
      url_settings = url_settings(authn_context: authn_context, name_identifier_value: session&.uuid)
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      connect_param = "&connect=#{connect}"
      link = saml_auth_request.create(url_settings, saml_options(success_relay: success_relay))
      connect.present? ? link + connect_param : link
    end

    # Builds the url to trigger SLO, caching the request
    def build_slo_url(session)
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      Rails.logger.info "New SP SLO for userid '#{session.uuid}'"

      url_settings = url_settings(name_identifier_value: session.uuid)
      # cache the request for session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
      logout_request.create(url_settings, saml_options)
    end

    def url_settings(options)
      saml_settings(options)
    end

    def saml_options(success_relay: nil)
      options = if Settings.saml.relays&.keys&.include?(success_relay)
                  { RelayState: Settings.saml.relays[success_relay] }
                elsif Settings.review_instance_slug
                  { RelayState: Settings.review_instance_slug }
                else
                  {}
                end
      options
    end
  end
end
