# frozen_string_literal: true

require 'va_profile/models/veteran_status'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'va_profile/configuration'

module VAProfileRedis
  class VeteranStatus < Common::RedisStore
    include Common::CacheAside

    redis_config_key :va_profile_veteran_status

    attr_accessor :user

    def self.for_user(user)
      veteran_status      = new
      veteran_status.user = user
      veteran_status.populate_from_redis

      veteran_status
    end

    def veteran?
      title38_status == 'V1'
    end

    def title38_status
      return unless @user.loa3?

      value_for('title38_status_code')
    end

    # Returns boolean for user being/not being considered a military person, by VA Profile,
    # based on their Title 38 Status Code.
    #
    # @return [Boolean]
    #
    def military_person?
      %w[V3 V6].include?(title38_status)
    end

    def status
      return VAProfile::Response::RESPONSE_STATUS[:not_authorized] unless @user.loa3?

      response.status
    end

    def response
      @response ||= response_from_redis_or_service
    end

    def populate_from_redis
      response_from_redis_or_service
    end

    private

    def value_for(key)
      value = response&.title38_status_code&.send(key)

      value.presence
    end

    def response_from_redis_or_service
      unless VAProfile::Configuration::SETTINGS.veteran_status.cache_enabled
        return veteran_status_service.get_veteran_status
      end

      do_cached_with(key: @user.uuid) do
        veteran_status_service.get_veteran_status
      end
    end

    def veteran_status_service
      @service ||= VAProfile::VeteranStatus::Service.new(@user)
    end
  end
end
