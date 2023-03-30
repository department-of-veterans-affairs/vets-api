# frozen_string_literal: true

require 'securerandom'
require 'active_support/notifications'
module Flipper
  module Instrumentation
    class EventSubscriber
      def call(*args)
        event = ActiveSupport::Notifications::Event.new(*args)
        operation = event.payload[:operation]

        # Only log changes to toggle state. Don't log exist?, enabled?, state, on, off
        if %i[enable disable add remove clear].include? operation
          FeatureToggleEvent.create(feature_name: event.payload[:feature_name],
                                    operation:,
                                    gate_name: event.payload[:gate_name],
                                    value: event.payload[:thing]&.value,
                                    user: RequestStore.store[:flipper_user_email_for_log])
        end
      end

      ActiveSupport::Notifications.subscribe(/feature_operation.flipper/, new)
    end
  end
end
