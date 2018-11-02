# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require_relative './retrieve_info_response'

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
          EVSS::Dependents::Service.new(@user).retrieve
        end.body
      end
    end
  end
end
