# frozen_string_literal: true

require_relative 'add_parser'
require 'common/client/concerns/service_status'

module MPI
  module Responses
    # Cacheable response from MVI's add person endpoint (prpa_in201301_uv02).
    class AddPersonResponse
      include Virtus.model(nullify_blank: true)
      include Common::Client::Concerns::ServiceStatus

      # @return [String] The status of the response
      attribute :status, String

      # @return [Array] The parsed response mvi codes
      attribute :mvi_codes, Array[Hash], coerce: false

      # @return [Common::Exceptions::BackendServiceException] The rescued exception
      attribute :error, Common::Exceptions::BackendServiceException

      # Builds a response with a server error status and a nil mvi_codes
      #
      # @return [MPI::Responses::AddPersonResponse] the response
      def self.with_server_error(exception = nil)
        AddPersonResponse.new(
          status: AddPersonResponse::RESPONSE_STATUS[:server_error],
          mvi_codes: nil,
          error: exception
        )
      end

      # Builds a response with a variable status and a nil mvi_codes. The status
      # should represent the status returned from the orchestrated search.
      #
      # @return [MPI::Responses::AddPersonResponse] the response
      def self.with_failed_orch_search(status, exception = nil)
        AddPersonResponse.new(
          status: status,
          mvi_codes: nil,
          error: exception
        )
      end

      # Builds a response with a ok status and a codes response
      #
      # @param response [Ox::Element] ox element returned from the soap service middleware
      # @return [MPI::Responses::AddPersonResponse] response with a possible parsed codes
      def self.with_parsed_response(type, response)
        add_parser = AddParser.new(response)
        mvi_codes = add_parser.parse

        raise MPI::Errors::InvalidRequestError, add_parser.error_details(mvi_codes) if add_parser.invalid_request?
        raise MPI::Errors::FailedRequestError, add_parser.error_details(mvi_codes) if add_parser.failed_request?

        Rails.logger.info("[MPI][Responses][AddPersonResponse] #{type}, " \
                          "icn=#{mvi_codes[:icn]}, " \
                          "idme_uuid=#{mvi_codes[:idme_uuid]}, " \
                          "logingov_uuid=#{mvi_codes[:logingov_uuid]}, " \
                          "transaction_id=#{mvi_codes[:transaction_id]}")
        AddPersonResponse.new(
          status: RESPONSE_STATUS[:ok],
          mvi_codes: mvi_codes
        )
      end

      def ok?
        @status == RESPONSE_STATUS[:ok]
      end

      def server_error?
        @status == RESPONSE_STATUS[:server_error]
      end
    end
  end
end
