# frozen_string_literal: true

module MockedAuthentication
  class RedirectUrlGenerator
    attr_reader :state, :code, :error

    def initialize(state:, code:, error:)
      @state = state
      @code = code
      @error = error
    end

    def perform
      redirect_uri.query = redirect_uri_params.to_query
      redirect_uri.to_s
    end

    private

    def redirect_uri
      @redirect_uri ||= URI.parse(sign_in_callback_uri)
    end

    def redirect_uri_params
      @redirect_uri_params ||= begin
        params = {}
        params[:code] = code if code
        params[:state] = state
        params[:error] = error if error
        params
      end
    end

    def sign_in_callback_uri
      '/v0/sign_in/callback'
    end
  end
end
