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
      renderer.render(template: 'oauth_get_form',
                      locals: { url: redirect_uri, params: redirect_uri_params },
                      format: :html)
    end

    private

    def redirect_uri
      @redirect_uri ||= client_config.redirect_uri
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

    def renderer
      @renderer ||= begin
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
        renderer
      end
    end
  end
end
