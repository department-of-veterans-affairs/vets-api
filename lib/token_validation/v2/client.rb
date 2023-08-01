# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module TokenValidation
  module V2
    class Client < Common::Client::Base
      configuration TokenValidation::V2::Configuration

      def initialize(api_key:)
        @api_key = api_key
      end

      def token_valid?(audience:, token:, scope:)
        json = URI.encode_www_form({ 'aud': audience })
        headers = {
          'apiKey': @api_key,
          'Authorization': "Bearer #{token}",
          'Content-Type': 'application/x-www-form-urlencoded'
        }
        response = perform(:post, 'v2/validation', json, headers)

        return false unless response.status == 200

        token_permits_scope?(scope:, response:)
      end

      private

      def token_permits_scope?(scope:, response:)
        permitted_scopes = permitted_scopes(response:)
        permitted_scopes.include?(scope)
      end

      def permitted_scopes(response:)
        JSON.parse(response.body)['data']['attributes']['scp']
      end
    end
  end
end
