# frozen_string_literal: true

require 'sign_in/logingov/risc_event'

module SignIn
  module Logingov
    class RiscEventHandler
      STATSD_KEY = 'api.sign_in.logingov.risc_event'

      attr_reader :payload

      def initialize(payload:)
        @payload = payload.deep_symbolize_keys
      end

      def perform
        risc_event = SignIn::Logingov::RiscEvent.new(event: payload[:events])
        risc_event.validate!

        handle_event(risc_event)
      rescue ActiveModel::ValidationError => e
        Rails.logger.error('[SignIn][Logingov][RiscEventHandler] validation error',
                           error: e.message,
                           risc_event: risc_event.to_h_masked)
        raise SignIn::Errors::LogingovRiscEventHandlerError.new message: "Invalid RISC event: #{e.message}"
      end

      private

      def handle_event(risc_event)
        log_event(risc_event)
        increment_metric(risc_event)
      end

      def log_event(risc_event)
        Rails.logger.info('[SignIn][Logingov][RiscEventHandler] risc_event received',
                          risc_event: risc_event.to_h_masked)
      end

      def increment_metric(risc_event)
        StatsD.increment(STATSD_KEY, tags: ["event_type:#{risc_event.event_type}"])
      end
    end
  end
end
