# frozen_string_literal: true

module SignIn
  class LoginRedirectUrlGenerator
    attr_reader :client_config, :login_code, :client_state, :type

    def initialize(user_code_map:)
      @login_code = user_code_map.login_code
      @type = user_code_map.type
      @client_config = user_code_map.client_config
      @client_state = user_code_map.client_state
    end

    def perform
      redirect_uri.query = redirect_uri_params.to_query
      redirect_uri.to_s
    end

    private

    def redirect_uri
      @redirect_uri ||= URI.parse(client_config.redirect_uri)
    end

    def redirect_uri_params
      @redirect_uri_params ||= begin
        params = {}
        params[:code] = login_code
        params[:type] = type
        params[:state] = client_state if client_state.present?
        params
      end
    end
  end
end
