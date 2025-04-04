# frozen_string_literal: true

module UserAudit
  module Appenders
    class Base < SemanticLogger::Subscriber
      REQUIRED_PAYLOAD_KEYS = %i[status identifier subject_user_verification_id].freeze

      def initialize(filter: /UserAudit/, level: :info, **args, &)
        super(filter:, level:, **args, &)
      end

      def log(log)
        @payload  = log.payload
        @tags     = log.named_tags
        @log_time = log.time || Time.zone.now

        append_log
      rescue => e
        log_error('Error appending log', e, log)
      end

      def should_log?(log)
        super(log) && valid_log?(log)
      rescue => e
        log_error('Error validating log', e, log)
      end

      private

      attr_reader :payload, :tags, :log_time

      def append_log
        raise NotImplementedError, 'Subclasses must implement #append_log'
      end

      def valid_log?(log)
        missing_keys = REQUIRED_PAYLOAD_KEYS - log.payload.compact_blank.keys
        return true if missing_keys.empty?

        log_error("Missing required log payload keys: #{missing_keys.join(', ')}", nil, log)
        false
      end

      def user_action_event
        @user_action_event ||= UserActionEvent.find_by!(identifier: payload[:identifier])
      end

      def acting_user_verification_id
        @acting_user_verification_id ||= payload[:acting_user_verification_id] || subject_user_verification_id
      end

      def subject_user_verification_id
        @subject_user_verification_id ||= payload[:subject_user_verification_id]
      end

      def status
        @status ||= payload[:status]
      end

      def acting_ip_address
        @acting_ip_address ||= tags[:ip]
      end

      def acting_user_agent
        @acting_user_agent ||= tags[:user_agent]
      end

      def log_error(message, exception, log)
        Rails.logger.error(
          "#{self.class.name} error: #{message}",
          audit_log: { log_payload: log.payload, log_tags: log.named_tags },
          error_message: exception&.message,
          backtrace: caller
        )
      end

      def default_formatter
        SemanticLogger::Formatters::Json.new
      end
    end
  end
end
