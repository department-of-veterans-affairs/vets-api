# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'sentry_logging'

module OktaRedis
  class Model < Common::RedisStore
    include Common::CacheAside
    include SentryLogging

    attr_accessor :id, :user

    REDIS_CONFIG_KEY = :okta_response

    %i[id user].each do |option|
      define_singleton_method "with_#{option}" do |val|
        redis_config_key(self::REDIS_CONFIG_KEY)

        okta_model = new
        okta_model.send("#{option}=", val)
        okta_model
      end
    end

    private

    def get_identifier
      @id || @user.uuid
    end

    def cache_key
      "#{class_name}.#{get_identifier}"
    end

    def class_name
      self.class::CLASS_NAME
    end

    def service
      @service ||= Okta::Service.new
    end
  end
end
