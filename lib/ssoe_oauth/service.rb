# frozen_string_literal: true

require 'uri'

module SSOeOAuth
  class Service < Common::Client::Base
    configuration SSOeOAuth::Configuration

    CLIENT_ID = Settings.ssoe_auth.client_id
    TOKEN_TYPE_HINT = 'access_token'
    INTROSPECT_PATH = '/oauthe/sps/oauth/oauth20/introspect'

    def post_introspect(token)
      params = {
        client_id: CLIENT_ID,
        token: token,
        token_type_hint: TOKEN_TYPE_HINT
      }
      encoded_params = URI.encode_www_form(params)
      perform(:post, INTROSPECT_PATH, encoded_params, { 'Content-Type' => 'application/x-www-form-urlencoded' })
    end
  end
end
