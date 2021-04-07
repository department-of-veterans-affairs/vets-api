module AppealsApi
  class EventsWorker
    include Sidekiq::Worker

    def perform(event_type, opts)
      EventSubscription.where(topic: event_type).each do |subscription|
        subscription.callback.new(opts).send(event_type)
      end
    end
  end
end
