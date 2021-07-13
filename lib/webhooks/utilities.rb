# frozen_string_literal: true
require 'json_schemer'
require 'uri'

module Webhooks
  module Utilities
    include Common::Exceptions

    class << self
      attr_reader :supported_events
      attr_reader :event_to_api_name
      attr_reader :api_name_to_time_block

      def included base
        base.extend ClassMethods
      end

      def register_name_to_event(name, event)
        @event_to_api_name ||={}
        @event_to_api_name[event] = name
      end

      def register_name_to_time_block(name, block)
        @api_name_to_time_block ||={}
        @api_name_to_time_block[name] = block
      end

      def register_event(event)
        @supported_events ||= []
        @supported_events << event
        @supported_events.uniq!
      end
    end

    module ClassMethods

      def register_events(*event, **keyword_args, &block)
        raise ArgumentError.new("Block required to yield next exectution time!") unless block_given?
        raise ArgumentError.new("api_name argument required") unless keyword_args.has_key? :api_name
        api_name = keyword_args[:api_name]
        event.each { |e|
          Webhooks::Utilities.register_event(e)
          Webhooks::Utilities.register_name_to_event(api_name, e)
          Webhooks::Utilities.register_name_to_time_block(api_name, block)
        }
      end

      def fetch_events(subscription)
        subscription['subscriptions'].map do |e|
          e['event']
        end.uniq
      end

      def register_webhook(consumer_id, consumer_name, subscription, api_guid)
        seen_api = []
        registrations = []
        Webhooks::Utilities.fetch_events(subscription).each do |event|
          api_name = Webhooks::Utilities.event_to_api_name[event]
          seen_api << api_name
          if (seen_api.length > 1 && api_guid)
            raise ArgumentError.new "This registration is tied to an api guid. At most one api name allowed!"
          end
          wh = WebhookSubscription.new
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
        webhook_urls = WebhookSubscription.get_notification_urls(
            api_name: api, consumer_id: consumer_id, event: event, api_guid: api_guid)

        notifications = []
        webhook_urls.each do |url|
          wh_notify = WebhookNotification.new
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

    # Validates a subscription request for an upload submission.  Returns an object representing the subscription
    def validate_subscription(subscriptions)
      schema_path = Pathname.new('modules/vba_documents/spec/fixtures/subscriptions/webhook_subscriptions_schema.json')
      schemer_formats = {
          'valid_urls' => lambda { |urls, _schema_info| validate_urls(urls) },
          'valid_events' => lambda { |subscription, _schema_info| validate_events(subscription) }

      }
      schemer = JSONSchemer.schema(schema_path, formats: schemer_formats)
      unless schemer.valid?(subscriptions)
        example_data = JSON.parse(File.read('./modules/vba_documents/spec/fixtures/subscriptions/subscriptions.json'))
        raise SchemaValidationErrors, ["Invalid subscription! Body must match the included example\n#{example_data}"]
      end
      subscriptions
    end

    def validate_events(subscriptions)
      events = subscriptions.map { |s| s['event'] }
      unsupported_events = events - Webhooks::Utilities.supported_events
      if ((unsupported_events).length > 0)
        raise SchemaValidationErrors, ["Invalid Event(s) submitted! #{unsupported_events}"]
      end
      true
    end

    def validate_url(url)
      begin
        uri = URI(url)
      rescue URI::InvalidURIError
        raise SchemaValidationErrors, [ "Invalid subscription! URI does not parse: #{url}"]
      end
      https = uri.scheme.eql? 'https'
      if !https && Settings.vba_documents.websockets.require_https #todo move this setting outside of vba_documents
        raise SchemaValidationErrors, ["Invalid subscription! URL #{url} must be https!"]
      end

      true
    end

    def validate_urls(urls)
      valid = true
      urls.each do |url|
        valid &= validate_url(url)
      end
      valid
    end
  end
end

require_dependency './lib/webhooks/registrations'

