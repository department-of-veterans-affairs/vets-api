# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    # Callback class used by VA Notify delivery status webhook pipeline.
    # Persists notification delivery events to VANotify::Notification table
    # so we can later query notification_id by confirmation_number.
    class EmailDeliveryStatusCallback
      def call(event)
        attrs = {
          notification_id: event.notification_id,
          status: event.respond_to?(:status) ? event.status : nil,
          status_reason: event.respond_to?(:status_reason) ? event.status_reason : nil,
          template_id: event.respond_to?(:template_id) ? event.template_id : nil,
          to: event.respond_to?(:to) ? event.to : nil,
          completed_at: event.respond_to?(:completed_at) ? event.completed_at : nil,
          sent_at: event.respond_to?(:sent_at) ? event.sent_at : nil,
          callback_metadata: event.respond_to?(:callback_metadata) ? event.callback_metadata : nil
        }.compact

        notification = VANotify::Notification.find_or_initialize_by(notification_id: attrs[:notification_id])
        notification.assign_attributes(attrs.except(:notification_id))
        notification.save!
      rescue => e
        Rails.logger.error('SimpleForms EmailDeliveryStatusCallback failure', {
                             error_class: e.class.name,
                             error_message: e.message,
                             notification_id: event&.notification_id
                           })
        raise e
      end
    end
  end
end
