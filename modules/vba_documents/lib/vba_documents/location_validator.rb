# frozen_string_literal: true
require 'json_schemer'
require 'uri'

module VBADocuments
  module LocationValidations
    SUPPORTED_EVENTS = %w(gov.va.developer.benefits.status_change)

    # perhaps we should consider a json validator?
    # Validates a subscription request for an upload submission.  Returns an array representing the subscription
    def validate_subscription(subscription)
      subscription = subscription.read if subscription.respond_to? :read
      subscription_array = JSON.parse(subscription)
      unless subscription_array.is_a? Array
        raise ArgumentError.new("Invalid Subscription! Subscription should be an Array!")
      end
      subscription_array.each do |e|
        raise ArgumentError.new("Invalid Subscription! Subscription items should be Objects!") unless e.is_a? Hash
        raise ArgumentError.new("Invalid Subscription! Subscription item needs a url!") unless e.has_key?('url')
        validate_url(e['url'])
        unless e.has_key?('events')
          raise ArgumentError.new("Invalid Subscription! Subscription item needs an array of events!")
        end
        e['events'].each do |event|
          unless SUPPORTED_EVENTS.include?(event)
            raise ArgumentError.new("Invalid Subscription! event type #{event} is not supported!")
          end
        end
      end
      subscription_array
    end

    def validate_url(url)
      uri = URI(url) # raises URI::InvalidURIError if URI doesn't parse
      https = uri.scheme.eql? 'https'
      if (!https && Settings.vba_documents.websockets.require_https)
        raise ArgumentError.new("URL #{url} must be https!")
      end
    end

  end
end
=begin
load('./modules/vba_documents/lib/vba_documents/location_validator.rb')
json = File.read('./modules/vba_documents/spec/fixtures/subscriptions.json')
=end
