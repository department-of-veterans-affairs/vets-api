# frozen_string_literal: true
require_relative 'base'
require_relative 'profile_parser'

module MVI
  module Responses
    # Parses the response for the find candidate endpoint (prpa_in201306_uv02).
    #
    # = Usage
    # The original response is a complex Hash of the xml returned by MVI.
    # See specs/support/mvi/savon_response_body.json for an example of the hierarchy
    #
    # Example:
    #  response = MVI::Responses::FindCandidate.new(mvi_response)
    #
    class FindProfileResponse < Common::RedisStore
      redis_store REDIS_CONFIG['mvi_profile_response']['namespace']
      redis_ttl REDIS_CONFIG['mvi_profile_response']['each_ttl']
      redis_key :uuid

      attribute :uuid
      attribute :status
      attribute :profile

      RESPONSE_STATUS = {
        ok: 'OK',
        not_found: 'NOT_FOUND',
        server_error: 'SERVER_ERROR',
        not_authorized: 'NOT_AUTHORIZED'
      }.freeze

      def self.with_server_error
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:server_error],
          profile: nil
        )
      end

      def self.with_not_found
        FindProfileResponse.new(
          status: FindProfileResponse::RESPONSE_STATUS[:not_found],
          profile: nil
        )
      end

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
