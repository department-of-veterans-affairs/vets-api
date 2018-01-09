# frozen_string_literal: true

require_relative 'profile_parser'
require 'common/models/redis_store'
require 'common/client/concerns/service_status'
require 'mvi/models/mvi_profile'

module MVI
  module Responses
    # Cacheable response from MVI's find profile endpoint (prpa_in201306_uv02).
    class FindProfileResponse
      include Virtus.model(nullify_blank: true)
      include Common::Client::ServiceStatus

      # @return [String] The status of the response
      attribute :status, String

      # @return [MVI::Models::MviProfile] The parsed MVI profile
      attribute :profile, MVI::Models::MviProfile

      # Builds a response with a server error status and a nil profile
      #
      # @return [MVI::Responses::FindProfileResponse] the response
      def self.with_server_error
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:server_error],
          profile: nil
        )
      end

      # Builds a response with a not found status and a nil profile
      #
      # @return [MVI::Responses::FindProfileResponse] the response
      def self.with_not_found
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:not_found],
          profile: nil
        )
      end

      # Builds a response with a ok status and a parsed response
      #
      # @param response [Ox::Element] ox element returned from the soap service middleware
      # @return [MVI::Responses::FindProfileResponse] response with a parsed MviProfile
      def self.with_parsed_response(response)
        profile_parser = ProfileParser.new(response)
        raise MVI::Errors::RecordNotFound if profile_parser.multiple_match?
        raise MVI::Errors::ServiceError if profile_parser.failed_or_invalid?
        profile = profile_parser.parse
        raise MVI::Errors::RecordNotFound unless profile
        FindProfileResponse.new(
          status: RESPONSE_STATUS[:ok],
          profile: profile
        )
      rescue MVI::Errors::ServiceError
        MVI::Responses::FindProfileResponse.with_server_error
      rescue MVI::Errors::RecordNotFound
        MVI::Responses::FindProfileResponse.with_not_found
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
