# frozen_string_literal: true

module SAML
  # This class is responsible for providing the requests for the various SSO and SLO endpoints.
  # It provides a similar interface to {SAML::URLService}, but for most endpoints it returns an SSO URL and
  # form request parameters for use in a SAML POST submission, instead of a self-contained redirect URL.
  #
  # @see SAML::URLService
  #
  class PostURLService < URLService
    # rubocop:disable Metrics/ParameterLists
    def initialize(saml_settings, session: nil, user: nil, params: {},
                   loa3_context: LOA::IDME_LOA3_VETS, previous_saml_uuid: nil)
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
        @type = JSON.parse(params[:RelayState])['type']
      end
      @query_params = {}
      @tracker = initialize_tracker(params, previous_saml_uuid: previous_saml_uuid)

      Raven.extra_context(params: params)
      Raven.user_context(session: session, user: user)
    end
    # rubocop:enable Metrics/ParameterLists

    def should_uplevel?
      user.loa[:current] < user.loa[:highest]
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def login_redirect_url(auth: 'success', code: nil)
      if auth == 'success'
        # if the original auth request specified a redirect, use that
        redirect_target = @tracker&.payload_attr(:redirect)
        return redirect_target if redirect_target.present?
      end

      # if the original auth request was an inbound ssoe autologin (type custom)
      # and authentication failed, set 'force-needed' so the FE can silently fail
      # authentication and NOT show the user an error page
      auth = 'force-needed' if auth != 'success' && @tracker&.payload_attr(:type) == 'custom'

      @query_params[:type] = type if type
      @query_params[:auth] = auth if auth != 'success'
      @query_params[:code] = code if code

      if Settings.saml.relay.present?
        add_query(Settings.saml.relay, query_params)
      else
        add_query("#{base_redirect_url}#{LOGIN_REDIRECT_PARTIAL}", query_params)
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def logout_redirect_url
      "#{base_redirect_url}#{LOGOUT_REDIRECT_PARTIAL}"
    end

    # logout URL for SSOe
    def ssoe_slo_url
      Settings.saml_ssoe.logout_url
    end

    private

    # Builds the urls to trigger various SSO policies: mhv, dslogon, idme, mfa, or verify flows.
    # link_authn_context is the new proposed authn_context
    def build_sso_url(link_authn_context)
      new_url_settings = url_settings
      new_url_settings.authn_context = link_authn_context
      saml_auth_request = OneLogin::RubySaml::Authrequest.new
      save_saml_request_tracker(saml_auth_request.uuid, link_authn_context)
      post_params = saml_auth_request.create_params(new_url_settings, 'RelayState' => relay_state_params)
      login_url = new_url_settings.idp_sso_target_url
      [login_url, post_params]
    end
  end
end
