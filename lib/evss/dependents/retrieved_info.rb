# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

module EVSS
  module Dependents
    class RetrievedInfo < Common::RedisStore
      include Common::CacheAside

      redis_config_key :evss_dependents_retrieve_response

      attr_accessor :user

      def self.for_user(user)
        ri = RetrievedInfo.new
        ri.user = user
        ri
      end

      def body
        do_cached_with(key: "evss_dependents_retrieve_#{@user.uuid}") do
          raw_response = EVSS::Dependents::Service.new(@user).retrieve
          EVSS::Dependents::RetrieveInfoResponse.new(raw_response.status, raw_response)
        end.body
      end

      def delete
        self.class.delete("evss_dependents_retrieve_#{@user.uuid}")
      end
    end
  end
end
