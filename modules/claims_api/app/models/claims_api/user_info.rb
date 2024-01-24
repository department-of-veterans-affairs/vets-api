# frozen_string_literal: true

require 'rest-client'

module ClaimsApi
  class UserInfo
    def initialize(user_info_url, token_string, audience)
      payload = { aud: audience }
      response = RestClient.post(user_info_url,
                                 payload,
                                 { Authorization: "Bearer #{token_string}",
                                   apiKey: Settings.claims_api.token_validation.api_key })

      raise Common::Exceptions::TokenValidationError.new(detail: 'Token validation error') if response.nil?

      @user_info_content = JSON.parse(response.body) if response.code == 200
    end

    attr_reader :user_info_content
  end
end
