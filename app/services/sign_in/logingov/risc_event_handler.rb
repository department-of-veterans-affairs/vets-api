# frozen_string_literal: true

require 'sign_in/logingov/risc_event'

module SignIn
  module Logingov
    class RiscEventHandler
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
        Rails.logger.info('[SignIn][Logingov][RiscEventHandler] risc_event received',
                          risc_event: risc_event.to_h_masked)
      end
    end
  end
end
