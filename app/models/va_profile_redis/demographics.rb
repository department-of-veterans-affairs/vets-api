# frozen_string_literal: true

require 'va_profile/demographics/service'
require 'va_profile/demographics/demographic_response'
require 'va_profile/models/demographic'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'va_profile/configuration'

module VAProfileRedis
  class Demographics < Common::RedisStore
    include Common::CacheAside

    redis_config_key :va_profile_demographics_response

    attr_accessor :user

    def self.for_user(user)
      demographic_fetcher = new
      demographic_fetcher.user = user
      demographic_fetcher.populate_from_redis
      demographic_fetcher
    end

    def demographics
      return unless @user.loa3?

      response&.demographics
    end

    def response
      @response ||= response_from_redis_or_service
    end

    def populate_from_redis
      response_from_redis_or_service
    end

    private

    def response_from_redis_or_service
      return demographic_service.get_demographics unless VAProfile::Configuration::SETTINGS.demographics.cache_enabled

      do_cached_with(key: @user.uuid) do
        demographic_service.get_demographics
      end
    end

    def demographic_service
      @service ||= VAProfile::Demographics::Service.new @user
    end
  end
end
