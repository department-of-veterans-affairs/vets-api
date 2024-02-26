# frozen_string_literal: true

module SignIn
  class RedirectUrlGenerator
    attr_reader :redirect_uri, :params_hash, :terms_code, :terms_redirect_uri

    def initialize(redirect_uri:, terms_redirect_uri: nil, terms_code: nil, params_hash: {})
      @redirect_uri = redirect_uri
      @terms_redirect_uri = terms_redirect_uri
      @terms_code = terms_code
      @params_hash = params_hash
    end

    def perform
      renderer.render(template: 'oauth_get_form',
                      locals: { url: full_redirect_uri },
                      format: :html)
    end

    private

    def full_redirect_uri
      if terms_code
        Rails.logger.info('Redirecting to /terms-of-use', type: :sis)
        return terms_of_use_redirect_url
      end

      original_redirect_uri_with_params
    end

    def original_redirect_uri_with_params
      "#{redirect_uri}?#{params_hash.to_query}"
    end

    def renderer
      @renderer ||= begin
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
        renderer
      end
    end

    def terms_of_use_redirect_url
      "#{terms_redirect_uri}?#{terms_of_use_params.to_query}"
    end

    def terms_of_use_params
      { redirect_url: original_redirect_uri_with_params, terms_code: }
    end
  end
end
