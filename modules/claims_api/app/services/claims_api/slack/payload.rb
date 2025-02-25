# frozen_string_literal: true

# fork of slack-notify gem to support blocks
module ClaimsApi
  module Slack
    class Payload
      attr_accessor :username,
                    :text,
                    :channel,
                    :icon_url,
                    :icon_emoji,
                    :link_names,
                    :unfurl_links,
                    :blocks

      def initialize(options = {})
        @username     = options[:username] || 'webhookbot'
        @channel      = options[:channel]  || '#general'
        @text         = options[:text]
        @icon_url     = options[:icon_url]
        @icon_emoji   = options[:icon_emoji]
        @link_names   = options[:link_names]
        @unfurl_links = options[:unfurl_links] || '1'
        @blocks       = options[:blocks]

        @channel = "##{@channel}" unless channel[0] =~ /^(#|@)/
      end

      def to_hash
        hash = {
          text:,
          username:,
          channel:,
          icon_url:,
          icon_emoji:,
          link_names:,
          unfurl_links:,
          blocks:
        }

        hash.delete_if { |_, v| v.nil? }
      end
    end
  end
end
