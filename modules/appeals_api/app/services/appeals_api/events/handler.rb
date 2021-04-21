# frozen_string_literal: true

module AppealsApi
  module Events
    class Handler
      def self.subscribe(topic_name, callback_name)
        AppealsApi::EventSubscription.find_or_create_by!(
          topic: topic_name,
          callback: callback_name
        )
      end

      def initialize(event_type:, opts:)
        @event_type = event_type
        @opts = opts
      end

      def handle!
        AppealsApi::EventsWorker.perform_async(event_type, opts)
      end

      private

      attr_accessor :event_type, :opts
    end
  end
end
