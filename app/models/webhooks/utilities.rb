# frozen_string_literal: true

require 'json_schemer'
require 'uri'

# data structures built up at class load time then frozen.  This is threadsafe.
# rubocop:disable ThreadSafety/InstanceVariableInClassMethod
module Webhooks
  module Utilities
    module ClassMethods
      # todo exercise having an event span multiple api_names
      def register_webhook(consumer_id, consumer_name, subscription, api_guid)
        seen_api = []
        registrations = []
        Webhooks::Utilities.fetch_events(subscription).each do |event|
          api_name = Webhooks::Utilities.event_to_api_name[event]
          seen_api << api_name
          if seen_api.length > 1 && api_guid #todo do we want to eliminate && api_guid?
            raise ArgumentError, 'This registration is tied to an api guid. At most one api name allowed!'
          end

          wh = Webhooks::Subscription.new
          wh.api_name = api_name
          wh.consumer_id = consumer_id
          wh.consumer_name = consumer_name
          wh.events = subscription
          wh.api_guid = api_guid if api_guid
          wh.save!
          registrations << wh
        end
        registrations
      end

      def record_notification(consumer_id:, consumer_name:, event:, api_guid:, msg:)
        api = Webhooks::Utilities.event_to_api_name[event]
        webhook_urls = Webhooks::Subscription.get_notification_urls(
            api_name: api, consumer_id: consumer_id, event: event, api_guid: api_guid
        )

        notifications = []
        webhook_urls.each do |url|
          wh_notify = Webhooks::Notification.new
          wh_notify.api_name = api
          wh_notify.consumer_id = consumer_id
          wh_notify.consumer_name = consumer_name
          wh_notify.api_guid = api_guid
          wh_notify.event = event
          wh_notify.callback_url = url
          wh_notify.msg = msg
          notifications << wh_notify
        end
        ActiveRecord::Base.transaction { notifications.each(&:save!) }
      end
    end
    extend ClassMethods
  end
end
# rubocop:enable ThreadSafety/InstanceVariableInClassMethod



