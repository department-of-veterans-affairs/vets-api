# frozen_string_literal: true

module ClaimsApi
  module CcgTokenValidation
    extend ActiveSupport::Concern

    included do
      def validate_ccg_token!
        request_method_to_scope = {
          'GET' => 'system/claim.read',
          'PUT' => 'system/claim.write',
          'POST' => 'system/claim.write'
        }
        token_attributes = @validated_token_data['attributes']
        token_scopes = token_attributes['scp']
        @is_valid_ccg_flow ||= @is_valid_ccg_flow && token_scopes.include?(request_method_to_scope[request.method])
        raise ::Common::Exceptions::Forbidden unless @is_valid_ccg_flow
      end
    end
  end
end
