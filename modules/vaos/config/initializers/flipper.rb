# frozen_string_literal: true

require 'securerandom'
require 'active_support/notifications'

module Flipper
  module Instrumentation
    class AppointmentsEventSubscriber
      # va_online_scheduling_poc_type_of_care used for temporary testing purposes in staging, will be removed
      # va_online_scheduling_unit_testing used for unit testing purposes
      CRITICAL_FEATURES = %i[
        va_online_scheduling
        va_online_scheduling_cancel
        va_online_scheduling_community_care
        va_online_scheduling_direct
        va_online_scheduling_requests
        va_online_scheduling_poc_type_of_care
        va_online_scheduling_unit_testing
      ].freeze
      RESTRICTED_OPERATIONS = %i[disable remove clear].freeze
      ALL_OPERATIONS = %i[enable disable add remove clear].freeze

      def call(*)
        event = ActiveSupport::Notifications::Event.new(*)
        operation = event.payload[:operation]
        feature_name = event.payload[:feature_name]

        # Warn if critical features are disabled
        if CRITICAL_FEATURES.include?(feature_name) && RESTRICTED_OPERATIONS.include?(operation)
          Rails.logger.warn("Restricted operation for critical appointments feature: #{operation} #{feature_name}")
        # Log other changes to toggle state. Don't log exist?, enabled?
        elsif feature_name.start_with?('va_online_scheduling') && ALL_OPERATIONS.include?(operation)
          Rails.logger.info("Routine operation for appointments feature: #{operation} #{feature_name}")
        end
      end
    end
  end
end

ActiveSupport::Notifications.subscribe('feature_operation.flipper',
                                       Flipper::Instrumentation::AppointmentsEventSubscriber.new)
