# frozen_string_literal: true
require 'json_schemer'
require 'uri'

module Webhooks
  module Utilities

    class << self
      attr_reader :supported_events

      def included base
        base.extend ClassMethods
      end

      def register_event(event)
        @supported_events ||= []
        @supported_events << event
        @supported_events.uniq!
      end
    end

    module ClassMethods
      def register_events(*events)
        events.each do |event|
          Webhooks::Utilities.register_event(event)
        end
      end

      def register_webhook(consumer_id, consumer_name, subscription, api_guid)
        puts "--------------- we are in register_webhook ------------------------"
        puts "subscription is #{subscription}"
        puts "consumer id is #{consumer_id}"
        puts "consumer name is #{consumer_name}"
        puts "api guid is #{api_guid}"
        puts "subscription is a? #{subscription.class}"
        subscription_info = validate_subscription(subscription) # throws exception
        wh = WebhookSubscription.new
        wh.api_name = 'gov.va.developer.benefits-intake' #subscription_info['api_name']
        wh.consumer_id = consumer_id
        wh.consumer_name = consumer_name
        wh.events = subscription
        wh.api_guid = api_guid if api_guid
        wh.save!
        wh
      end


      def api_name(event)
        str_arr = event.split('.')
        str_arr.pop # remove the event
        str_arr.join('.')
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
        example_data = JSON.parse(File.read('./modules/vba_documents/spec/fixtures/subscriptions/subscription.json'))
        raise ArgumentError.new({
                                    'Error' => 'Invalid subscription! Body must match the included example',
                                    'Example' => example_data
                                })
      end
      subscriptions
    end

    def validate_events(subscriptions)
      events = subscriptions.map { |s| s['event'] }
      unsupported_events = events - Webhooks::Utilities.supported_events
      if ((unsupported_events).length > 0)
        raise ArgumentError.new({'Error' => "Invalid Event(s) submitted! #{unsupported_events}"})
      end
      true
    end

    def validate_url(url)
      begin
        uri = URI(url)
      rescue URI::InvalidURIError
        raise ArgumentError.new({'Error' => "Invalid subscription! URI does not parse: #{url}"})
      end
      https = uri.scheme.eql? 'https'
      if !https && Settings.vba_documents.websockets.require_https #todo move this setting outside of vba_documents
        raise ArgumentError.new({'Error' => "Invalid subscription! URL #{url} must be https!"})
      end

      true
    end

    def validate_urls(urls)
      p '=================================================================='
      p urls
      p '=================================================================='
      valid = true
      urls.each do |url|
        valid &= validate_url(url)
      end
      valid
    end
  end
end
  #   SUPPORTED_EVENTS = %w(
  #    gov.va.developer.benefits-intake.status_change
  #    gov.va.developer.claims.initiate_filing
  #    gov.va.developer.claims.decision_rendered
  # ) # pull from settings.yml

  # INVALID_SINGLE_API_MSG = 'Invalid webhook subscription. The subscription contained events for multiple APIs.'
  # INVALID_EVENTS_MSG = 'Invalid webhook subscription. Invalid event value specified in the submission.'
  # INVALID_NO_SUBSCRIPTION_MSG = 'Invalid webhook subscription. There must include a subscriptions key.'
  # INVALID_WEBHOOK_URLS = 'Invalid webhook subscription. Invalid url(s) included in the submission.'


  # {
  #     "subscriptions": [
  #         {
  #             "event": "gov.va.developer.benefits-intake.status_change",
  #             "urls": ["https://benefits.consumer.com/i/am/listening",
  #                      "https://benefits.consumer.com/i/am/also/listening"]
  #         }
  #     ]
  # }
  # def self.validate_subscription(subscription)
  #   # validate that this has all valid events based on SUPPORTED_EVENTS
  #   subscriptions = subscription['subscriptions']
  #   raise INVALID_NO_SUBSCRIPTION_MSG unless subscriptions
  #
  #   # validate all of the events
  #   valid_events = []
  #   api_list = []
  #
  #   subscriptions.each do |e|
  #     event = e['event']
  #     valid_events << Webhooks::Validator.event_valid?(event)
  #     api_list << self.app_name(event)
  #   end
  #
  #   # todo create WebhookValidator error class
  #   raise INVALID_EVENTS_MSG unless valid_events.all?
  #   raise ArgumentError.new(INVALID_SINGLE_API_MSG) unless api_list.uniq.count == 1
  #
  #   # validate all urls
  #   valid_urls = []
  #   subscriptions.each do |e|
  #     valid_urls << e.has_key?('urls')
  #
  #     # if e['urls'].is_a?(Array)
  #     #   valid_urls << e['urls'].each {|u| valid_url?(u)} unless e['urls'].empty?
  #     # else
  #     #   valid_urls << false
  #     # end
  #   end
  #   raise INVALID_WEBHOOK_URLS unless valid_urls.all?
  #   {api_name: api_list.uniq, events: subscriptions}
  # end

  # def self.app_name(event)
  #   raise "Invalid webhook event #{event}" unless event_valid?(event)
  #   str_arr = event.split('.')
  #   str_arr.pop # remove the event
  #   str_arr.join('.')
  # end

  # def self.valid_url!(url)
  #   uri = URI(url) # raises URI::InvalidURIError if URI doesn't parse
  #   https = uri.scheme.eql? 'https'
  #   if (!https && Settings.vba_documents.websockets.require_https)
  #     raise ArgumentError.new("URL #{url} must be https!") # todo create a custom webhook validation error
  #   end
  # end
  #
  # def self.valid_url?(url)
  #   return valid_url!(url) rescue false
  # end
  #
  # private
  #
  # def self.event_valid?(event)
  #   SUPPORTED_EVENTS.include? event
  # end
