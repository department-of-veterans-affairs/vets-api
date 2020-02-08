# frozen_string_literal: true

require_relative 'add_parser'
require 'common/client/concerns/service_status'

module MVI
  module Responses
    # Cacheable response from MVI's add person endpoint (prpa_in201301_uv02).
    class AddPersonResponse
      include Virtus.model(nullify_blank: true)
      include Common::Client::ServiceStatus

      # @return [String] The status of the response
      attribute :status, String

      # @return [Array] The parsed response codes
      attribute :codes, Array

      # @return [Common::Exceptions::BackendServiceException] The rescued exception
      attribute :error, Common::Exceptions::BackendServiceException

      # Builds a response with a server error status and a nil codes
      #
      # @return [MVI::Responses::AddPersonResponse] the response
      def self.with_server_error(exception = nil)
        AddPersonResponse.new(
          status: AddPersonResponse::RESPONSE_STATUS[:server_error],
          codes: nil,
          error: exception
        )
      end

      def self.with_failed_orch_search(exception = nil)
        AddPersonResponse.new(
          status: AddPersonResponse::RESPONSE_STATUS[:server_error],
          codes: nil,
          error: exception
        )
      end

      # Builds a response with a ok status and a codes response
      #
      # @param response [Ox::Element] ox element returned from the soap service middleware
      # @return [MVI::Responses::AddPersonResponse] response with a possible parsed codes
      def self.with_parsed_response(response)
        add_parser = AddParser.new(response)
        codes = add_parser.parse
        raise MVI::Errors::InvalidRequestError.new(codes), 'InvalidRequest' if add_parser.invalid_request?
        raise MVI::Errors::FailedRequestError.new(codes), 'FailedRequest' if add_parser.failed_request?

        AddPersonResponse.new(
          status: RESPONSE_STATUS[:ok],
          codes: codes
        )
      end

      def ok?
        @status == RESPONSE_STATUS[:ok]
      end

      def not_found?
        @status == RESPONSE_STATUS[:not_found]
      end

      def server_error?
        @status == RESPONSE_STATUS[:server_error]
      end
    end
  end
end
