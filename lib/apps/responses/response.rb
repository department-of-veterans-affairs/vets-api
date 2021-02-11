# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'common/models/base'

module Apps
  module Responses
    ##
    # Model for Apps responses. Body is passed straight through from the service
    # with a validation check that it matches the expected schema.
    #
    # @!attribute body
    #   @return [Hash] Validated response body.
    # @!attribute status
    #   @return [Integer] The HTTP status code.
    #
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(status, body, schema_name)
        self.body = if status == 204
                      nil
                    else
                      json_format_is_valid?(body, schema_name) ? body : {}
                    end
        self.status = status
      end

      private

      def json_format_is_valid?(body, schema_name)
        schema_path = Rails.root.join('lib', 'apps', 'schemas', "#{schema_name}.json").to_s
        JSON::Validator.validate!(schema_path, body, strict: false)
      end
    end
  end
end
