# frozen_string_literal: true

# This file was previously config/initializers/raven.rb

require 'sentry/event_scrubber'

# This custom Transport class is need to log the error
# This needs to be manually tested
# https://github.com/getsentry/sentry-ruby/issues/1583
transport = Class.new(Sentry::HTTPTransport) do
  def send_data(data)
    super
  rescue Sentry::ExternalError => e
    Rails.logger.error(
      "Error performing Sentry#send_data: #{e.message}",
      original_event: data
    )
    StatsD.increment('worker.sentry.error')
  end
end

Rails.application.reloader.to_prepare do
  Sentry.init do |config|
    config.dsn = Settings.sentry.dsn if Settings.sentry.dsn
    config.environment = Settings.vsp_environment if Settings.vsp_environment

    # https://docs.sentry.io/platforms/ruby/guides/rails/configuration/options/#transport-options
    config.transport.transport_class = transport

    # Sentry removed processors
    # https://docs.sentry.io/platforms/ruby/migration/#removed-processors
    config.before_send = lambda do |event, hint|
      return Sentry::EventScrubber.new(event, hint).cleaned_event
    end
  end
end
