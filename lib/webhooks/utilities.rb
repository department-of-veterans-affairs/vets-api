# frozen_string_literal: true

require 'json_schemer'
require 'uri'

# data structures built up at class load time then frozen.  This is threadsafe.
# rubocop:disable ThreadSafety/InstanceVariableInClassMethod
module Webhooks
  module Utilities
    include Common::Exceptions

    SUBSCRIPTION_EX = JSON.parse(File.read('./modules/vba_documents/spec/fixtures/subscriptions/subscriptions.json'))

    class << self
      attr_reader :supported_events, :event_to_api_name, :api_name_to_time_block, :api_name_to_retries

      def included(base)
        base.extend ClassMethods
      end

      def register_name_to_retries(name, retries)
        @api_name_to_retries ||= {}
        @api_name_to_retries[name] = retries.to_i
      end

      def api_registered?(api_name)
        @event_to_api_name.values.include?(api_name)
      rescue
        false
      end

      def register_name_to_event(name, event)
        @event_to_api_name ||= {}
        @event_to_api_name[event] = name
      end

      def register_name_to_time_block(name, block)
        @api_name_to_time_block ||= {}
        @api_name_to_time_block[name] = block
      end

      def register_event(event)
        @supported_events ||= []
        if @supported_events.include?(event)
          raise ArgumentError, "Event: #{event} previously registered! api_name: #{event_to_api_name[event]}"
        end

        @supported_events << event
        @supported_events.uniq!
      end
    end

    module ClassMethods
      def register_events(*event, **keyword_args, &block)
        raise ArgumentError, 'Block required to yield next execution time!' unless block_given?
        raise ArgumentError, 'api_name argument required' unless keyword_args.key? :api_name

        api_name = keyword_args[:api_name]
        max_retries = keyword_args[:max_retries]
        if Webhooks::Utilities.api_registered?(api_name)
          raise ArgumentError, "api name: #{api_name} previously registered!"
        end

        event.each do |e|
          Webhooks::Utilities.register_event(e)
          Webhooks::Utilities.register_name_to_event(api_name, e)
          Webhooks::Utilities.register_name_to_retries(api_name, max_retries)
          Webhooks::Utilities.register_name_to_time_block(api_name, block)
        end
      end

      def fetch_events(subscription)
        subscription['subscriptions'].map do |e|
          e['event']
        end.uniq
      end
    end
    extend ClassMethods

    # Validates a subscription request for an upload submission.  Returns an object representing the subscription
    def validate_subscription(subscriptions)
      # TODO: move out of vba documents
      schema_path = Pathname.new('modules/vba_documents/spec/fixtures/subscriptions/webhook_subscriptions_schema.json')
      schemer_formats = {
        'valid_urls' => ->(urls, _schema_info) { validate_urls(urls) },
        'valid_events' => ->(subscription, _schema_info) { validate_events(subscription) }

      }
      schemer = JSONSchemer.schema(schema_path, formats: schemer_formats)
      unless schemer.valid?(subscriptions)
        raise SchemaValidationErrors, ["Invalid subscription! Body must match the included example\n#{SUBSCRIPTION_EX}"]
      end

      subscriptions
    end

    def validate_events(subscriptions)
      events = subscriptions.select { |s| s.key?('event') }.map { |s| s['event'] }
      raise SchemaValidationErrors, ["Duplicate Event(s) submitted! #{events}"] if Set.new(events).size != events.length

      unsupported_events = events - Webhooks::Utilities.supported_events

      if unsupported_events.length.positive?
        raise SchemaValidationErrors, ["Invalid Event(s) submitted! #{unsupported_events}"]
      end

      true
    end

    def validate_url(url)
      begin
        uri = URI(url)
      rescue URI::InvalidURIError
        raise SchemaValidationErrors, ["Invalid subscription! URI does not parse: #{url}"]
      end
      https = uri.scheme.eql? 'https'
      if !https && Settings.webhooks.require_https
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
# rubocop:enable ThreadSafety/InstanceVariableInClassMethod
# ADD YOUR REGISTRATIONS BELOW
require './lib/webhooks/registrations'
# ADD YOUR REGISTRATIONS ABOVE
# Rails.env = 'test'
unless Rails.env.test?
  Webhooks::Utilities.supported_events.freeze
  Webhooks::Utilities.event_to_api_name.freeze
  Webhooks::Utilities.api_name_to_time_block.freeze
  Webhooks::Utilities.api_name_to_retries.freeze
end
