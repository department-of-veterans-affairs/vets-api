# frozen_string_literal: true

module ClaimsApi
  module CcgTokenValidation
    extend ActiveSupport::Concern

    included do
      def validate_ccg_token!
        client = TokenValidation::V2::Client.new(api_key: Settings.claims_api.token_validation.api_key)
        root_url = request.base_url == 'https://api.va.gov' ? 'https://api.va.gov' : 'https://sandbox-api.va.gov'
        claims_audience = "#{root_url}/services/claims"
        request_method_to_scope = {
          'GET' => 'system/claim.read',
          'PUT' => 'system/claim.write',
          'POST' => 'system/claim.write'
        }

        @is_valid_ccg_flow ||= client.token_valid?(audience: claims_audience,
                                                   scope: request_method_to_scope[request.method],
                                                   token:)
        raise ::Common::Exceptions::Forbidden unless @is_valid_ccg_flow
      end
    end
  end
end
