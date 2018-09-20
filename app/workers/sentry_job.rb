# frozen_string_literal: true

class SentryJob
  include Sidekiq::Worker

  sidekiq_options queue: 'tasker', retry: false

  def perform(event)
    Raven.send_event(event)
  rescue StandardError => e
    Rails.logger.error(
      "Error performing SentryJob: #{e.message}",
      original_culprit: event&.culprit,
      original_extra: event&.extra,
      original_backtrace: event&.backtrace
    )
  end
end
