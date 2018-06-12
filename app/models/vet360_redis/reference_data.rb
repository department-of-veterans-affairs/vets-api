# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module Vet360Redis
  # Facade for Vet360::ReferenceData::Service.
  #
  # When reference data is requested from the serializer, it returns either
  # a cached response from Redis or from the Vet360::ReferenceData::Service.
  class ReferenceData < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    redis_config_key :vet360_reference_data_response

    # List of valid Vet360 countries
    # @return [Vet360::ReferenceData::CountriesResponse]
    def countries
      response_from_redis_or_service(:countries)
    end

    # List of valid Vet360 states
    # @return [Vet360::ReferenceData::StatesResponse]
    def states
      response_from_redis_or_service(:states)
    end

    # List of valid Vet360 zipcodes
    # @return [Vet360::ReferenceData::ZipcodesResponse]
    def zipcodes
      response_from_redis_or_service(:zipcodes)
    end

    private

    def response_from_redis_or_service(endpoint)
      do_cached_with(key: "vet360_reference_data_#{endpoint}") do
        reference_data_service.public_send(endpoint)
      end
    end

    def reference_data_service
      @service ||= Vet360::ReferenceData::Service.new
    end
  end
end
