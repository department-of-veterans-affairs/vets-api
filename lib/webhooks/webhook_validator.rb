# frozen_string_literal: true

module Webhooks
  module Validator
    SUPPORTED_EVENTS = %w(
       gov.va.developer.benefits-intake.status_change
       gov.va.developer.claims.initiate_filing
       gov.va.developer.claims.decision_rendered
    ) # pull from settings.yml

    INVALID_SINGLE_API_MSG = 'Invalid webhook subscription. The subscription contained events for multiple APIs.'
    INVALID_EVENTS_MSG = 'Invalid webhook subscription. Invalid event value specified in the submission.'
    INVALID_NO_SUBSCRIPTION_MSG = 'Invalid webhook subscription. There must include a subscriptions key.'
    INVALID_WEBHOOK_URLS = 'Invalid webhook subscription. Invalid url(s) included in the submission.'

    def self.register_webhook(consumer_id, consumer_name, subscription, api_guid)
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

    # {
    #     "subscriptions": [
    #         {
    #             "event": "gov.va.developer.benefits-intake.status_change",
    #             "urls": ["https://benefits.consumer.com/i/am/listening",
    #                      "https://benefits.consumer.com/i/am/also/listening"]
    #         }
    #     ]
    # }
    def self.validate_subscription(subscription)
      # validate that this has all valid events based on SUPPORTED_EVENTS
      subscriptions = subscription['subscriptions']
      raise INVALID_NO_SUBSCRIPTION_MSG unless subscriptions

      # validate all of the events
      valid_events = []
      api_list = []

      subscriptions.each do |e|
        event = e['event']
        valid_events << Webhooks::Validator.event_valid?(event)
        api_list << self.app_name(event)
      end

      # todo create WebhookValidator error class
      raise INVALID_EVENTS_MSG unless valid_events.all?
      raise ArgumentError.new(INVALID_SINGLE_API_MSG) unless api_list.uniq.count == 1

      # validate all urls
      valid_urls = []
      subscriptions.each do |e|
        valid_urls << e.has_key?('urls')

        # if e['urls'].is_a?(Array)
        #   valid_urls << e['urls'].each {|u| valid_url?(u)} unless e['urls'].empty?
        # else
        #   valid_urls << false
        # end
      end
      raise INVALID_WEBHOOK_URLS unless valid_urls.all?
      {api_name: api_list.uniq, events: subscriptions}
    end

    def self.app_name(event)
      raise "Invalid webhook event #{event}" unless event_valid?(event)
      str_arr = event.split('.')
      str_arr.pop # remove the event
      str_arr.join('.')
    end

    def self.valid_url!(url)
      uri = URI(url) # raises URI::InvalidURIError if URI doesn't parse
      https = uri.scheme.eql? 'https'
      if (!https && Settings.vba_documents.websockets.require_https)
        raise ArgumentError.new("URL #{url} must be https!") # todo create a custom webhook validation error
      end
    end

    def self.valid_url?(url)
      return valid_url!(url) rescue false
    end

    private

    def self.event_valid?(event)
      SUPPORTED_EVENTS.include? event
    end
  end
end
