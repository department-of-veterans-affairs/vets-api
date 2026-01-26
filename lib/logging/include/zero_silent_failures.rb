# frozen_string_literal: true

module Logging
  module Include
    # global monitoring functions for ZSF - statsd and logging
    module ZeroSilentFailures
      # record metrics and log for a silent failure
      #
      # @param context [Hash] information to accompany the log to aid in debugging
      # @param user_account_uuid [UUID]
      # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged
      def log_silent_failure(context, user_account_uuid = nil, call_location: nil)
        metric = 'silent_failure'
        message = 'Silent failure!'

        call_location ||= caller_locations.first
        track_request(:error, message, metric, call_location:, user_account_uuid:, **context)
      end

      # record metrics and log for a silent failure, avoided - an email was sent
      #
      # @param context [Hash] information to accompany the log to aid in debugging
      # @param user_account_uuid [UUID]
      # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged
      def log_silent_failure_avoided(context, user_account_uuid = nil, call_location: nil)
        metric = 'silent_failure_avoided'
        message = 'Silent failure avoided'

        call_location ||= caller_locations.first
        track_request(:error, message, metric, call_location:, user_account_uuid:, **context)
      end

      # record metrics and log for a silent failure, avoided - an email was sent with no callback
      #
      # @param context [Hash] information to accompany the log to aid in debugging
      # @param user_account_uuid [UUID]
      # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged
      def log_silent_failure_no_confirmation(context, user_account_uuid = nil, call_location: nil)
        metric = 'silent_failure_avoided_no_confirmation'
        message = 'Silent failure avoided (no confirmation)'

        call_location ||= caller_locations.first
        track_request(:error, message, metric, call_location:, user_account_uuid:, **context)
      end
    end
  end
end
