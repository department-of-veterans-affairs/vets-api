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

    # Vet360 country reference data
    # [{ "country_name": "Afghanistan",
    #    "country_code_iso2": "AF",
    #    "country_code_iso3": "AFG",
    #    "country_code_fips": "AF" }, ...]
    # @return [Array[Hash]] List of countries Vet360 recognizes as valid
    def countries
      response_from_redis_or_service(:countries).reference_data
    end

    # Vet360 state reference data
    # [{ "state_name": "Ohio", "state_code": "OH" }, ...]
    # @return [Array[Hash]] List of states Vet360 recognizes as valid
    def states
      response_from_redis_or_service(:states).reference_data
    end

    # Vet360 zipcode reference data
    # [{ "zip_code": "12345" }, ...]
    # @return [Array[Hash]] List of zipcodes Vet360 recognizes as valid
    def zipcodes
      response_from_redis_or_service(:zipcodes).reference_data
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
