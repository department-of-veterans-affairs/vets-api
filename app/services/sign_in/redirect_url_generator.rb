# frozen_string_literal: true

module SignIn
  class RedirectUrlGenerator
    attr_reader :redirect_uri, :params_hash

    def initialize(redirect_uri:, params_hash: {})
      @redirect_uri = redirect_uri
      @params_hash = params_hash
    end

    def perform
      renderer.render(template: 'oauth_get_form',
                      locals: { url: redirect_uri_with_params },
                      format: :html)
    end

    private

    def redirect_uri_with_params
      "#{redirect_uri}?#{params_hash.to_query}"
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
