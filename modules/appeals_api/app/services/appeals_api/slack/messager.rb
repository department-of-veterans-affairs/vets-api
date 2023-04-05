# frozen_string_literal: true

require 'common/client/base'

module AppealsApi
  module Slack
    class Messager
      API_PATH = 'https://slack.com/api/chat.postMessage'

      REGISTERED_NOTIFICATIONS = %i[error_retry stuck_record].freeze
      ENVIRONMENT_EMOJIS = { production: 'rotating_light', sandbox: 'rocket', staging: 'construction',
                             development: 'brain', localhost: 'test_tube' }.freeze

      def initialize(params, notification_type: :default, slack_channel: slack_channel_id)
        @params = params
        @notification_type = notification_type
        @slack_channel = slack_channel
      end

      def notify!
        Faraday.post(API_PATH, request_body, request_headers)
      end

      private

      attr_reader :params, :notification_type, :slack_channel

      def notification
        "AppealsApi::Slack::#{notification_type.to_s.classify}Notification".constantize.new(params)
      rescue NameError
        raise UnregisteredNotificationType, "registered notifications: #{REGISTERED_NOTIFICATIONS}"
      end

      def request_body
        {
          text: notification.message_text,
          channel: slack_channel
        }.to_json
      end

      def request_headers
        {
          'Content-type' => 'application/json; charset=utf-8',
          'Authorization' => "Bearer #{slack_api_token}"
        }
      end

      def slack_channel_id
        Settings.modules_appeals_api.slack.appeals_channel_id
      end

      def slack_api_token
        Settings.modules_appeals_api.slack.api_key
      end
    end

    class UnregisteredNotificationType < StandardError; end
  end
end
