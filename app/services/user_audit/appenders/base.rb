# frozen_string_literal: true

module UserAudit
  module Appenders
    class Base < SemanticLogger::Subscriber
      REQUIRED_PAYLOAD_KEYS = %i[status event user_verification].freeze

      def initialize(filter: /UserAudit/, level: :info, **args, &)
        super(filter:, level:, **args, &)
      end

      def log(log)
        @payload  = log.payload
        @tags     = log.named_tags
        @log_time = log.time || Time.zone.now

        append_log
        log_success
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
        @user_action_event ||= UserActionEvent.find_by!(identifier: payload[:event])
      end

      def acting_user_verification
        @acting_user_verification ||= payload[:acting_user_verification] || subject_user_verification
      end

      def subject_user_verification
        @subject_user_verification ||= payload[:user_verification]
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
          error_message: exception&.message
        )
      end

      def log_success
        Rails.logger.info(
          "#{self.class.name} log created",
          audit_log: { log_payload: payload, log_tags: tags },
          event_id: user_action_event.id,
          event_description: user_action_event.details,
          status:,
          user_action: user_action_event.id
        )
      end

      def default_formatter
        SemanticLogger::Formatters::Json.new
      end
    end
  end
end
