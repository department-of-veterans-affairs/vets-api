# frozen_string_literal: true

class SentryJob
  include Sidekiq::Worker

  sidekiq_options queue: 'tasker'

  def perform(event)
    Raven.send_event(event)
  end
end
