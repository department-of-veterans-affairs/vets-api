# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require_relative 'retrieve_info_response'
require_relative 'service'

module EVSS
  module Dependents
    ##
    # Model for caching a user's retrieved info.
    #
    # @!attribute user
    #   @return [User] User object.
    #
    class RetrievedInfo < Common::RedisStore
      include Common::CacheAside

      redis_config_key :evss_dependents_retrieve_response

      attr_accessor :user

      ##
      # Fetches retreived info for a user
      #
      # @param user [User] user object
      # @return [RetrievedInfo] an instance of the class with an assigned user
      #
      def self.for_user(user)
        ri = RetrievedInfo.new
        ri.user = user
        ri
      end

      ##
      # Creates a cached instance of a user's retrieved info
      #
      # @return [Hash] Retrieved info response body
      #
      def body
        do_cached_with(key: "evss_dependents_retrieve_#{@user.uuid}") do
          raw_response = EVSS::Dependents::Service.new(@user).retrieve
          EVSS::Dependents::RetrieveInfoResponse.new(raw_response.status, { response_body: raw_response.body })
        end.response_body
      end

      ##
      # Deletes retrieved info cache
      #
      def delete
        self.class.delete("evss_dependents_retrieve_#{@user.uuid}")
      end
    end
  end
end
