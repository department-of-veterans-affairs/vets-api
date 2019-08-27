# frozen_string_literal: true

module Appeals
  module Responses
    ##
    # Model for a appeals' responses. Body is passed straight through from appeals
    # with a validation check that it matches the expected schema.
    #
    # @param body [String] The original body from the service.
    # @param status [Integer] The HTTP status code from the service.
    #
    # @!attribute body
    #   @return [Integer] Validated response body.
    # @!attribute status
    #   @return [Integer] The HTTP status code.
    #
    class Appeals < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(body, status)
        self.body = body if json_format_is_valid?(body)
        self.status = status
      end

      private

      def json_format_is_valid?(body)
        schema_path = Rails.root.join('lib', 'appeals', 'schema', 'appeals.json').to_s
        JSON::Validator.validate!(schema_path, body, strict: false)
      end
    end
  end
end
