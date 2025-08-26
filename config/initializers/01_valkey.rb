# frozen_string_literal: true

# environment specific valkey host and port (see: config/valkey.yml)
VALKEY_CONFIG = Rails.application.config_for(:valkey).freeze
# set the current global instance of Valkey based on environment specific config

$redis =
  if Rails.env.test?
    require 'mock_redis'
    MockRedis.new(url: VALKEY_CONFIG[:valkey][:url])
  else
    Redis.new(VALKEY_CONFIG[:valkey].to_h)
  end
