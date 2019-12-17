# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

# Facade for GIDS.
class GIDS < Common::RedisStore
  include Common::CacheAside

  REDIS_CONFIG_KEY = :gi_response
  redis_config_key REDIS_CONFIG_KEY

  # rest_call [Symbol] the GI::Client method to call
  # scrubbed_params [Hash] the params to be used with the rest_call
  attr_accessor :rest_call, :scrubbed_params

  # @return the response returned from GI Client
  def gi_response
    @gi_response ||= response_from_redis_or_service
  end

  # rubocop:disable Style/MethodMissingSuper
  def method_missing(name, *args)
    self.rest_call = name
    self.scrubbed_params = *args
    gi_response.body
  end
  # rubocop:enable Style/MethodMissingSuper

  def respond_to_missing?(_name, _include_private)
    true
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

  def save
    saved = super
    expire(record_ttl) if saved
    saved
  end

  def record_ttl
    REDIS_CONFIG[REDIS_CONFIG_KEY.to_s]['each_ttl']
  end
end
