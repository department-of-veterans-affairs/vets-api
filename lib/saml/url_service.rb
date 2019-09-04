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

    attr_reader :saml_settings, :session, :user, :authn_context, :type, :query_params

    def initialize(saml_settings, session: nil, user: nil, params: {})
      unless %w[new saml_callback saml_logout_callback].include?(params[:action])
        raise Common::Exceptions::RoutingError, params[:path]
      end

      if session.present?
        @session = session
        @user = user
        @authn_context = user&.authn_context
      end

      @saml_settings = saml_settings

      Raven.extra_context(params: params)
      Raven.user_context(session: session, user: user)
      initialize_query_params(params)
    end

    # REDIRECT_URLS
    def base_redirect_url
      VIRTUAL_HOST_MAPPINGS[current_host][:base_redirect]
    end

    # TODO: Does this level up flow still work smoothly after SSOe is put into the flow?
    def login_redirect_url(auth: 'success', code: nil)
      if auth == 'success' && user.loa[:current] < user.loa[:highest]
        verify_url
      else
        @query_params[:type] = type if type
        @query_params[:auth] = auth if auth == 'fail'
        @query_params[:code] = code if code
        add_query("#{base_redirect_url}#{LOGIN_REDIRECT_PARTIAL}", query_params)
      end
    end

    def logout_redirect_url
      "#{base_redirect_url}#{LOGOUT_REDIRECT_PARTIAL}"
    end

    # SIGN ON URLS
    def mhv_url
      @type = 'mhv'
      build_sso_url('myhealthevet')
    end

    def dslogon_url
      @type = 'dslogon'
      build_sso_url('dslogon')
    end

    def idme_url
      @type = 'idme'
      build_sso_url(LOA::IDME_LOA1)
    end

    def signup_url
      @type = 'signup'
      @query_params[:op] = 'signup'
      build_sso_url(LOA::IDME_LOA1)
    end

    def verify_url
      # For verification from a login callback, type should be the initial login policy.
      # In that case, it will have been set to the type from RelayState.
      @type ||= 'verify'

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
      @type = 'mfa'
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
      @type = 'slo'
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      # cache the request for session.token lookup when we receive the response
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
      Rails.logger.info "New SP SLO having logout_request '#{logout_request.uuid}' for userid '#{session.uuid}'"
      logout_request.create(url_settings, RelayState: relay_state_params)
    end

    private

    def initialize_query_params(params)
      @query_params = {}

      if params[:action] == 'saml_callback'
        @type = JSON.parse(params[:RelayState])['type'] if params[:RelayState]
      end
    end

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # link_authn_context is the new proposed authn_context
    def build_sso_url(link_authn_context)
      @query_params[:RelayState] = relay_state_params
      new_url_settings = url_settings
      new_url_settings.authn_context = link_authn_context
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      saml_auth_request.create(new_url_settings, query_params)
    end

    def relay_state_params
      { originating_request_id: Thread.current['request_id'], type: type }.to_json
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
      if params.any?
        uri = URI.parse(url)
        uri.query = Rack::Utils.parse_nested_query(uri.query).merge(params).to_query
        uri.to_s
      else
        url
      end
    end
  end
end
