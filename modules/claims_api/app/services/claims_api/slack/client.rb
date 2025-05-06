# frozen_string_literal: true

require 'json'
require 'faraday'

# fork of slack-notify gem to support blocks
module ClaimsApi
  module Slack
    class Client
      def initialize(options = {})
        @webhook_url  = options[:webhook_url]
        @username     = options[:username]
        @channel      = options[:channel]

        raise ArgumentError, 'Webhook URL required' if @webhook_url.nil?
      end

      def notify(text, blocks: nil, channel: nil)
        delivery_channels(channel).each do |chan|
          payload = ClaimsApi::Slack::Payload.new(
            text:,
            blocks:,
            channel: chan,
            username: @username,
            icon_url: @icon_url,
            icon_emoji: @icon_emoji,
            link_names: @link_names,
            unfurl_links: @unfurl_links
          )

          send_payload(payload)
        end

        true
      end

      private

      def delivery_channels(channel)
        [channel || @channel || '#general'].flatten.compact.uniq
      end

      def send_payload(payload)
        conn = Faraday.new(@webhook_url) do |c|
          c.use(Faraday::Request::UrlEncoded)
          c.adapter(Faraday.default_adapter)
          c.options.timeout      = 5
          c.options.open_timeout = 5
        end

        response = conn.post do |req|
          req.body = JSON.dump(payload.to_hash)
        end

        handle_response(response)
      end

      def handle_response(response)
        unless response.success?
          if response.body.include?("\n")
            raise SlackNotify::Error
          else
            raise SlackNotify::Error, response.body
          end
        end
      end
    end
  end
end
