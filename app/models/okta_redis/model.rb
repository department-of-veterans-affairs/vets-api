# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require_dependency 'emis/responses'

module OktaRedis
  class Model < Common::RedisStore
    include Common::CacheAside

    attr_accessor :user

    def self.for_user(user)
      redis_config_key(:okta_response)

      okta_model = new
      okta_model.user = user
      okta_model
    end

    private

    def cache_key(id)
      key = "#{class_name}.#{id}"
    end

    def class_name
      self.class::CLASS_NAME
    end

    def service
      @service ||= Okta::Service.new
    end
  end
end
