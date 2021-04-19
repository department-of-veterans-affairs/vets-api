# frozen_string_literal: true

module AppealsApi
  class EventsWorker
    include Sidekiq::Worker

    def perform(event_type, opts)
      log_event(event_type)

      EventSubscription.where(topic: event_type).each do |subscription|
        subscription.callback.new(opts).send(event_type)
      end
    end

    private

    def log_event(event_type)
      Rails.logger.info("AppealsApi: Event triggered - #{event_type}, job started at #{Time.zone.now}")
    end
  end
end
