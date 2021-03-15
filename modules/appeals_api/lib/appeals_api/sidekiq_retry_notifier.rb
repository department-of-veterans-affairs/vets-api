# frozen_string_literal: true

require 'common/client/base'

module AppealsApi
  class SidekiqRetryNotifier
    API_PATH = 'https://slack.com/api/chat.postMessage'

    class << self
      def notify!(params)
        Faraday.post(API_PATH) do |req|
          req.headers['Content-type'] = 'application/json; charset=utf-8'
          req.headers['Authorization'] = "Bearer #{slack_api_token}"
          req.body = {
            text: message_text(params),
            channel: slack_channel_id
          }.to_json
        end
      end

      def message_text(params)
        ''"
        The sidekiq job #{params['class']} has hit #{params['retry_count']} retries.
        \nError Type: #{params['error_class']} \n Error Message: \n #{params['error_message']} \n\n
This job failed at: #{Time.zone.at(params['failed_at'])}, and was retried at: #{Time.zone.at(params['retried_at'])}
        "''
      end

      private

      def slack_channel_id
        Settings.modules_appeals_api.slack.appeals_channel_id
      end

      def slack_api_token
        Settings.modules_appeals_api.slack.api_token
      end
    end
  end
end
