# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

# Facade for GIDS.
class GIDSRedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :gi_response

  # rest_call [Symbol] the GI::Client method to call
  # scrubbed_params [Hash] the params to be used with the rest_call
  attr_accessor :rest_call, :scrubbed_params

  # rubocop:disable Style/MethodMissingSuper
  def method_missing(name, *args)
    if respond_to?(name, nil)
      self.rest_call = name
      self.scrubbed_params = *args
      response_from_redis_or_service.body
    else
      super
    end
  end
  # rubocop:enable Style/MethodMissingSuper

  def respond_to_missing?(name, _include_private)
    gi_service.respond_to?(name)
  end

  private

  def response_from_redis_or_service
    do_cached_with(key: rest_call.to_s + scrubbed_params.to_s) do
      gi_service.send(rest_call, scrubbed_params)
    end
  end

  def gi_service
    @client ||= ::GI::Client.new
  end

  def record_ttl
    REDIS_CONFIG[REDIS_CONFIG_KEY.to_s]['each_ttl']
  end
end
