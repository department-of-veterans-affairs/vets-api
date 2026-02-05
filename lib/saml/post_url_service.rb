# frozen_string_literal: true

require 'common/exceptions/routing_error'
require_relative 'url_service'

module SAML
  # This class is responsible for providing the requests for the various SSO and SLO endpoints.
  # It provides a similar interface to {SAML::URLService}, but for most endpoints it returns an SSO URL and
  # form request parameters for use in a SAML POST submission, instead of a self-contained redirect URL.
  #
  # @see SAML::URLService
  #
  class PostURLService < URLService
    def initialize(saml_settings, session: nil, user: nil, params: {}, loa3_context: LOA::IDME_LOA3_VETS)
      unless %w[new saml_callback saml_logout_callback ssoe_slo_callback].include?(params[:action])
        raise Common::Exceptions::RoutingError, params[:path]
      end

      if session.present?
        @session = session
        @user = user
        @authn_context = user&.authn_context
      end

      @saml_settings = saml_settings
      @loa3_context = loa3_context

      if (params[:action] == 'saml_callback') && params[:RelayState].present?
        @type = JSON.parse(CGI.unescapeHTML(params[:RelayState]))['type']
      end
      @query_params = {}
      @tracker = initialize_tracker(params)

      Sentry.set_extras(params:)
      Sentry.set_user(session:, user:)
    end

    def login_redirect_url(auth: 'success', code: nil, request_id: nil)
      return client_redirect_target if auth == 'success' && @tracker.payload_attr(:redirect).present?

      # if the original auth request was an inbound ssoe autologin (type custom)
      # and authentication failed, set 'force-needed' so the FE can silently fail
      # authentication and NOT show the user an error page
      auth = 'force-needed' if auth != 'success' && @tracker&.payload_attr(:type) == 'custom'
      set_query_params(auth, code, request_id)

      if IdentitySettings.saml_ssoe.relay.present?
        add_query(IdentitySettings.saml_ssoe.relay, query_params)
      else
        add_query("#{base_redirect_url}#{LOGIN_REDIRECT_PARTIAL}", query_params)
      end
    end

    def logout_redirect_url
      "#{base_redirect_url}#{LOGOUT_REDIRECT_PARTIAL}"
    end

    def tou_declined_logout_redirect_url
      "#{base_redirect_url}#{TERMS_OF_USE_DECLINED_PATH}"
    end

    def terms_of_use_redirect_url
      if terms_of_use_enabled_application
        Rails.logger.info('Redirecting to /terms-of-use', type: :ssoe)
        add_query(terms_of_use_url, { redirect_url: login_redirect_url })
      else
        login_redirect_url
      end
    end

    private

    def terms_of_use_enabled_application
      cache_key = "terms_of_use_redirect_user_#{user.uuid}"
      cached_application = retrieve_and_delete_terms_of_use_redirect_user(cache_key)
      current_application = @tracker&.payload_attr(:application)
      write_terms_of_use_redirect_user(cache_key, current_application) if should_cache_application?(current_application)
      terms_of_use_redirect_enabled?(cached_application, current_application)
    end

    def terms_of_use_redirect_enabled?(cached_application, current_application)
      enabled_tou_clients.include?(cached_application || current_application || 'vaweb')
    end

    def should_cache_application?(application)
      enabled_tou_clients.include?(application)
    end

    def retrieve_and_delete_terms_of_use_redirect_user(cache_key)
      application = Rails.cache.read(cache_key)
      Rails.cache.delete(cache_key)
      application
    end

    def write_terms_of_use_redirect_user(cache_key, application)
      Rails.cache.write(cache_key, application, expires_in: 5.minutes)
    end

    def terms_of_use_url
      current_application = @tracker&.payload_attr(:application)

      base_url = if Settings.review_instance_slug.present?
                   "https://#{Settings.review_instance_slug}.vfs.va.gov/terms-of-use"
                 else
                   "#{base_redirect_url}/terms-of-use"
                 end

      if current_application.in?(SKIP_MHV_ACCOUNT_CREATION_CLIENTS) || @tracker&.payload_attr(:type) == 'custom'
        base_url = add_query(base_url, { skip_mhv_account_creation: true })
      end

      base_url
    end

    def client_redirect_target
      redirect_target = @tracker.payload_attr(:redirect)
      redirect_target += '&postLogin=true' if @tracker.payload_attr(:post_login) == 'true'
      redirect_target
    end

    def set_query_params(auth, code, request_id)
      @query_params[:type] = type if type
      @query_params[:auth] = auth if auth != 'success'
      @query_params[:code] = code if code
      @query_params[:request_id] = request_id unless request_id.nil?
    end

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, logingov, mfa, or verify flows.
    # link_authn_context is the new proposed authn_context
    def build_sso_url(link_authn_context, authn_con_compare = 'exact')
      new_url_settings = url_settings
      new_url_settings.authn_context = link_authn_context
      new_url_settings.authn_context_comparison = authn_con_compare
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      save_saml_request_tracker(saml_auth_request.uuid, link_authn_context)
      post_params = saml_auth_request.create_params(new_url_settings, 'RelayState' => relay_state_params)
      login_url = new_url_settings.idp_sso_service_url
      [login_url, post_params]
    end

    def enabled_tou_clients
      IdentitySettings.terms_of_use.enabled_clients.split(',').collect(&:strip)
    end
  end
end
