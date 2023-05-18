# frozen_string_literal: true

require 'json_schemer'
require 'uri'
require 'webhooks/utilities'

# data structures built up at class load time then frozen.  This is threadsafe.
module Webhooks
  module Utilities
    module ClassMethods
      # We assume the subscription parameter has already been through validate_subscription()
      def register_webhook(consumer_id, consumer_name, subscription, api_guid)
        event = subscription['subscriptions'].first['event']
        api_name = Webhooks::Utilities.event_to_api_name[event]
        wh = Webhooks::Subscription.new
        wh.api_name = api_name
        wh.consumer_id = consumer_id
        wh.consumer_name = consumer_name
        wh.events = subscription
        wh.api_guid = api_guid if api_guid
        wh.save!
        wh
      end

      def record_notifications(consumer_id:, consumer_name:, event:, api_guid:, msg:)
        api_name = Webhooks::Utilities.event_to_api_name[event]
        webhook_urls = Webhooks::Subscription.get_notification_urls(
          api_name:, consumer_id:, event:, api_guid:
        )
        return [] unless webhook_urls.size.positive?

        notifications = []
        webhook_urls.each do |url|
          wh_notify = Webhooks::Notification.new
          wh_notify.api_name = api_name
          wh_notify.consumer_id = consumer_id
          wh_notify.consumer_name = consumer_name
          wh_notify.api_guid = api_guid
          wh_notify.event = event
          wh_notify.callback_url = url
          wh_notify.msg = msg
          notifications << wh_notify
        end
        ActiveRecord::Base.transaction { notifications.each(&:save!) }
        notifications
      end
    end
    extend ClassMethods
  end
end
