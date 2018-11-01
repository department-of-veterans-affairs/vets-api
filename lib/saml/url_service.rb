# frozen_string_literal: true

module SAML
  # This class is responsible for providing the URLs for the various SSO and SLO endpoints
  class URLService
    attr_reader :saml_settings, :session, :authn_context

    def initialize(saml_settings, session: nil, user: nil)
      if session.present?
        @session = session
        @authn_context = session&.user&.authn_context || user&.authn_context
      end
      @saml_settings = saml_settings
    end

    def mhv_url
      build_sso_url('myhealthevet')
    end

    def dslogon_url
      build_sso_url('dslogon')
    end

    def idme_loa1_url
      build_sso_url(LOA::MAPPING.invert[1])
    end

    def idme_loa3_url
      link_authn_context = authn_context.present? ? "#{authn_context}_loa3" : LOA::MAPPING.invert[3]
      build_sso_url(link_authn_context)
    end

    def mfa_url
      link_authn_context = authn_context.present? ? "#{authn_context}_multifactor" : 'multifactor'
      build_sso_url(link_authn_context)
    end

    # SLO URLS
    # This is the internal vets-api url that first gets invoked, it should redirect without authentication
    # when this url gets invoked, the session should be destroyed, before the callback returns
    def logout_url
      token = Base64.urlsafe_encode64(session.token)
      Rails.application.routes.url_helpers.logout_v0_sessions_url(session: token)
    end

    def slo_url
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      # cache the request for session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
      Rails.logger.info "New SP SLO for userid '#{session.uuid}'"
      logout_request.create(url_settings)
    end

    private

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # link_authn_context is the new proposed authn_context
    def build_sso_url(link_authn_context)
      new_url_settings = url_settings
      new_url_settings.authn_context = link_authn_context
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      saml_auth_request.create(new_url_settings)
    end

    def url_settings
      url_settings = saml_settings.dup
      url_settings.name_identifier_value = session&.uuid
      url_settings
    end
  end
end
