# frozen_string_literal: true

class SentryJob
  include Sidekiq::Worker

  sidekiq_options queue: 'tasker', retry: false

  STATSD_ERROR_KEY = 'worker.sentry.error'

  def perform(event)
    Raven.send_event(event)
  rescue StandardError => e
    Rails.logger.error(
      "Error performing SentryJob: #{e.message}",
      original_event: event
    )
    StatsD.increment(STATSD_ERROR_KEY)
  end
end
