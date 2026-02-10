# frozen_string_literal: true

require 'securerandom'
require 'active_support/notifications'

module Flipper
  module Instrumentation
    class AppointmentsEventSubscriber
      # va_online_scheduling_subscriber_unit_testing used for unit testing purposes
      CRITICAL_FEATURES_SYMBOLS = %i[
        appointments_consolidation
        va_online_scheduling
        va_online_scheduling_community_care
        va_online_scheduling_direct
        va_online_scheduling_requests
        va_online_scheduling_subscriber_unit_testing
      ].freeze
      CRITICAL_FEATURES_NAMES = %w[
        appointments_consolidation
        va_online_scheduling
        va_online_scheduling_community_care
        va_online_scheduling_direct
        va_online_scheduling_requests
        va_online_scheduling_subscriber_unit_testing
      ].freeze
      RESTRICTED_OPERATIONS_SYMBOLS = %i[disable remove clear].freeze
      RESTRICTED_OPERATIONS_NAMES = %w[disable remove clear].freeze
      ALL_OPERATIONS_SYMBOLS = %i[enable disable add remove clear].freeze
      ALL_OPERATIONS_NAMES = %w[enable disable add remove clear].freeze

      def includes(symbols, names, target)
        names.include?(target) || symbols.include?(target)
      end

      def call(*)
        event = ActiveSupport::Notifications::Event.new(*)
        operation = event.payload[:operation]
        feature_name = event.payload[:feature_name]

        # Critical toggles
        if includes(CRITICAL_FEATURES_SYMBOLS, CRITICAL_FEATURES_NAMES, feature_name)
          # Error on restricted operations to critical toggles.
          if includes(RESTRICTED_OPERATIONS_SYMBOLS, RESTRICTED_OPERATIONS_NAMES, operation)
            Rails.logger.error("Restricted operation for critical appointments feature: #{operation} #{feature_name}")
          # Warn on other operations to critical toggles. Don't log exist?, enabled?
          elsif includes(ALL_OPERATIONS_SYMBOLS, ALL_OPERATIONS_NAMES, operation)
            Rails.logger.warn("Routine operation for critical appointments feature: #{operation} #{feature_name}")
          end
        # Info log for other operations to appointments toggles. Don't log exist?, enabled?
        elsif feature_name.start_with?('va_online_scheduling') && includes(ALL_OPERATIONS_SYMBOLS,
                                                                           ALL_OPERATIONS_NAMES, operation)
          Rails.logger.info("Routine operation for appointments feature: #{operation} #{feature_name}")
        end
      end
    end
  end
end

ActiveSupport::Notifications.subscribe('feature_operation.flipper',
                                       Flipper::Instrumentation::AppointmentsEventSubscriber.new)
