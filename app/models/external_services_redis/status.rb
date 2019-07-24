# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

module ExternalServicesRedis
  # Facade for the PagerDuty::ExternalServices::Service class.
  #
  class Status < Common::RedisStore
    include Common::CacheAside

    KEY = 'pager_duty_services'

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :external_service_statuses_response

    # The time from the call to PagerDuty's API
    #
    # @return [Time] For example, 2019-03-14 20:19:43 UTC
    #
    delegate :reported_at, to: :fetch_or_cache

    # Returns either the cached response from the
    # PagerDuty::ExternalServices::Service.new.get_services call, or makes
    # a fresh call to that endpoint, then caches and returns the response.
    #
    # @return [PagerDuty::ExternalServices::Response] An instance of the
    #   PagerDuty::ExternalServices::Response class
    # @example ExternalServicesRedis.new.fetch_or_cache.as_json
    #   {
    #     "status"      => 200,
    #     "reported_at" => "2019-03-14T19:47:47.000Z",
    #     "statuses"    => [
    #       {
    #         "service"                 => "Appeals",
    #         "service_id"              => "appeals"
    #         "status"                  => "active",
    #         "last_incident_timestamp" => "2019-03-01T02:55:55.000-05:00"
    #       },
    #       ...
    #     ]
    #   }
    #
    def fetch_or_cache
      @response ||= response_from_redis_or_service
    end

    # The HTTP status code from call to PagerDuty's API
    #
    # @return [Integer] For example, 200
    #
    def response_status
      fetch_or_cache.status
    end

    private

    def response_from_redis_or_service
      do_cached_with(key: KEY) do
        PagerDuty::ExternalServices::Service.new.get_services
      end
    end
  end
end
