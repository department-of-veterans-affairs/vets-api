# frozen_string_literal: true

module SignIn
  module SSOAuthorizable
    extend ActiveSupport::Concern

    included do
      skip_before_action :authenticate, only: :authorize_sso
      before_action :authenticate_authorize_sso, only: :authorize_sso
    end

    def authorize_sso
      validate_authorize_sso_params!

      user_code_map = authorize_sso_user_code_map
      response_params = { code: user_code_map.login_code,
                          type: user_code_map.type,
                          state: user_code_map.client_state }.compact_blank

      redirect_url = RedirectUrlGenerator.new(
        redirect_uri: user_code_map.client_config.redirect_uri,
        terms_code: user_code_map.terms_code,
        terms_redirect_uri: user_code_map.client_config.terms_of_use_url,
        params_hash: response_params
      ).perform

      log_authorize_sso_success
      render body: redirect_url, content_type: 'text/html', status: :found
    rescue Errors::MalformedParamsError => e
      handle_authorize_sso_error(e, :error)
    rescue => e
      handle_authorize_sso_error(e, :redirect)
    end

    private

    def authorize_sso_user_code_map
      client_id = authorize_sso_params[:client_id]
      code_challenge = authorize_sso_params[:code_challenge]
      code_challenge_method = authorize_sso_params[:code_challenge_method]
      client_state = authorize_sso_params[:state]
      user_attributes = AuthSSO::SessionValidator.new(access_token: @access_token, client_id:).perform

      state_payload_jwt = StatePayloadJwtEncoder.new(code_challenge:, code_challenge_method:, client_state:,
                                                     acr: user_attributes[:acr], type: user_attributes[:type],
                                                     client_config: client_config(client_id),
                                                     operation: Constants::Auth::AUTHORIZE_SSO).perform

      state_payload = StatePayloadJwtDecoder.new(state_payload_jwt:).perform

      UserCodeMapCreator.new(user_attributes:, state_payload:, verified_icn: user_attributes[:icn],
                             request_ip: request.remote_ip).perform
    end

    def authorize_sso_params
      @authorize_sso_params ||= params.permit(:client_id, :code_challenge, :code_challenge_method, :state)
    end

    def validate_authorize_sso_params!
      errors = [].tap do |err|
        err << 'client_id' if authorize_sso_params[:client_id].blank?
        err << 'code_challenge' if authorize_sso_params[:code_challenge].blank?

        unless authorize_sso_params[:code_challenge_method] == Constants::Auth::CODE_CHALLENGE_METHOD
          err << 'code_challenge_method'
        end
      end

      raise Errors::MalformedParamsError.new(message: "Invalid params: #{errors.join(', ')}") if errors.any?
    end

    def redirect_to_usip
      query_params = authorize_sso_params.to_h.merge(oauth: true)
      uri = URI.parse(IdentitySettings.sign_in.usip_uri)
      uri.query = query_params.to_query

      redirect_to uri, status: :found
    end

    def authenticate_authorize_sso
      access_token_authenticate(re_raise: true)
    rescue => e
      handle_authorize_sso_error(e, :redirect)
    end

    def handle_authorize_sso_error(error, handler)
      log_authorize_sso_error(error, handler)

      case handler
      when :error then render json: { error: error.message }, status: :bad_request
      when :redirect then redirect_to_usip
      end
    end

    def log_authorize_sso_success
      sign_in_logger.info('authorize sso', client_id: authorize_sso_params[:client_id])
      StatsD.increment(
        Constants::Statsd::STATSD_SIS_AUTHORIZE_SSO_SUCCESS,
        tags: ["client_id:#{authorize_sso_params[:client_id]}"]
      )
    end

    def log_authorize_sso_error(error, handler)
      statsd_key = if handler == :redirect
                     Constants::Statsd::STATSD_SIS_AUTHORIZE_SSO_REDIRECT
                   else
                     Constants::Statsd::STATSD_SIS_AUTHORIZE_SSO_FAILURE
                   end

      sign_in_logger.info("authorize sso #{handler}", error: error.message,
                                                      client_id: authorize_sso_params[:client_id])
      StatsD.increment(statsd_key)
    end
  end
end
