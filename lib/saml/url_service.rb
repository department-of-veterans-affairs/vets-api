# frozen_string_literal: true

module SAML
  # This class is responsible for providing the URLs for the various SSO and SLO endpoints
  class URLService
    VIRTUAL_HOST_MAPPINGS = {
      'https://api.vets.gov' => { base_redirect: 'https://www.vets.gov' },
      'https://staging-api.vets.gov' => { base_redirect: 'https://staging.vets.gov' },
      'https://dev-api.vets.gov' => { base_redirect: 'https://dev.vets.gov' },
      'https://api.va.gov' => { base_redirect: 'https://www.va.gov' },
      'https://staging-api.va.gov' => { base_redirect: 'https://staging.va.gov' },
      'https://dev-api.va.gov' => { base_redirect: 'https://dev.va.gov' },
      'http://localhost:3000' => { base_redirect: 'http://localhost:3001' },
      'http://127.0.0.1:3000' => { base_redirect: 'http://127.0.0.1:3001' }
    }.freeze

    LOGIN_REDIRECT_PARTIAL = '/auth/login/callback'
    LOGOUT_REDIRECT_PARTIAL = '/logout/'

    attr_reader :saml_settings, :session, :authn_context

    def initialize(saml_settings, session: nil, user: nil)
      if session.present?
        @session = session
        @authn_context = user&.authn_context
      end
      @saml_settings = saml_settings
    end

    # REDIRECT_URLS
    def base_redirect_url
      VIRTUAL_HOST_MAPPINGS[current_host][:base_redirect]
    end

    def login_redirect_url(params = {})
      add_query("#{base_redirect_url}#{LOGIN_REDIRECT_PARTIAL}", params)
    end

    def logout_redirect_url(params = {})
      add_query("#{base_redirect_url}#{LOGOUT_REDIRECT_PARTIAL}", params)
    end

    # SIGN ON URLS
    def mhv_url
      build_sso_url('myhealthevet')
    end

    def dslogon_url
      build_sso_url('dslogon')
    end

    def idme_loa1_url
      build_sso_url(LOA::IDME_LOA1)
    end

    def idme_loa3_url
      link_authn_context =
        case authn_context
        when LOA::IDME_LOA1, 'multifactor'
          LOA::IDME_LOA3
        when 'myhealthevet', 'myhealthevet_multifactor'
          'myhealthevet_loa3'
        when 'dslogon', 'dslogon_multifactor'
          'dslogon_loa3'
        end
      build_sso_url(link_authn_context)
    end

    def mfa_url
      link_authn_context =
        case authn_context
        when LOA::IDME_LOA1, LOA::IDME_LOA3
          'multifactor'
        when 'myhealthevet', 'myhealthevet_loa3'
          'myhealthevet_multifactor'
        when 'dslogon', 'dslogon_loa3'
          'dslogon_multifactor'
        end
      build_sso_url(link_authn_context)
    end

    # SIGN OFF URLS
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

    def current_host
      uri = URI.parse(saml_settings.assertion_consumer_service_url)
      URI.join(uri, '/').to_s.chop
    end

    def url_settings
      url_settings = saml_settings.dup
      url_settings.name_identifier_value = session&.uuid
      url_settings
    end

    def add_query(url, params)
      punctuation = url.include?('?') ? '&' : '?'
      url + (params.any? ? "#{punctuation}#{params.to_query}" : '')
    end
  end
end
