# frozen_string_literal: true
%w(server client).each do |type|
  Sidekiq.public_send("configure_#{type}") do |config|
    config.redis = REDIS_CONFIG['redis']
  end
end
