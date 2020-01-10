# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

# Facade for GIDS.
class GIDSRedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :gids_response

  # @return  [Symbol] the GI::Client method to call
  attr_accessor :rest_call

  # @return [Hash] the params to be used with the rest_call
  attr_accessor :scrubbed_params

  def method_missing(name, *args)
    if respond_to?(name)
      self.rest_call = name
      self.scrubbed_params = args.first
      response_from_redis_or_service.body
    else
      super
    end
  end

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
end
