# frozen_string_literal: true

require_relative 'profile_parser'
require 'common/models/redis_store'
require 'common/client/concerns/service_status'
require 'mpi/models/mvi_profile'

module MPI
  module Responses
    # Cacheable response from MVI's find profile endpoint (prpa_in201306_uv02).
    class FindProfileResponse
      include Virtus.model(nullify_blank: true)
      include Common::Client::Concerns::ServiceStatus

      # @return [String] The status of the response
      attribute :status, String

      # @return [MPI::Models::MviProfile] The parsed MVI profile
      attribute :profile, MPI::Models::MviProfile

      # @return [Common::Exceptions::BackendServiceException] The rescued exception
      attribute :error, Common::Exceptions::BackendServiceException

      # Builds a response with a server error status and a nil profile
      #
      # @return [MPI::Responses::FindProfileResponse] the response
      def self.with_server_error(exception = nil)
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:server_error],
          profile: nil,
          error: exception
        )
      end

      # Builds a response with a not found status and a nil profile
      #
      # @return [MPI::Responses::FindProfileResponse] the response
      def self.with_not_found(exception = nil)
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:not_found],
          profile: nil,
          error: exception
        )
      end

      # Builds a response with a ok status and a parsed response
      #
      # @param response [Ox::Element] ox element returned from the soap service middleware
      # @return [MPI::Responses::FindProfileResponse] response with a parsed MviProfile
      def self.with_parsed_response(response)
        profile_parser = ProfileParser.new(response)
        profile = profile_parser.parse
        raise MPI::Errors::DuplicateRecords, profile_parser.error_details if profile_parser.multiple_match?
        raise MPI::Errors::FailedRequestError, profile_parser.error_details if profile_parser.failed_request?
        raise MPI::Errors::RecordNotFound if profile_parser.invalid_request? || profile.nil?

        FindProfileResponse.new(
          status: RESPONSE_STATUS[:ok],
          profile: profile
        )
      end

      def cache?
        ok? || not_found?
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

      def cache_for_user(user)
        @uuid = user.uuid
        save
      end
    end
  end
end
