# frozen_string_literal: true

require 'common/client/base'

module VAForms
  module Slack
    class Messenger
      API_PATH = 'https://slack.com/api/chat.postMessage'
      ENVIRONMENT_EMOJIS = { production: 'rotating_light', sandbox: 'rocket', staging: 'construction',
                             development: 'brain', localhost: 'test_tube' }.freeze

      def initialize(params)
        @params = params
      end

      def notify!
        return unless Settings.va_forms.slack.enabled

        Faraday.post(API_PATH, request_body, request_headers)
      end

      private

      attr_reader :params

      def notification
        VAForms::Slack::HashNotification.new(params)
      end

      def request_body
        {
          text: notification.message_text,
          channel: slack_channel_id
        }.to_json
      end

      def request_headers
        {
          'Content-type' => 'application/json; charset=utf-8',
          'Authorization' => "Bearer #{slack_api_token}"
        }
      end

      def slack_channel_id
        Settings.va_forms.slack.channel_id
      end

      def slack_api_token
        Settings.va_forms.slack.api_key
      end
    end
  end
end
