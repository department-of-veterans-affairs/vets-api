# frozen_string_literal: true

require 'common/client/base'

module AppealsApi
  class SidekiqRetryNotifier
    class << self
      def notify!(params)
        Faraday.post(slack_api_path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['Authorization'] = 'application/json'
          req.body = {
            text: message_text(params)
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

      def slack_api_path
        "#{base_path}/#{slack_team_id}/#{slack_channel_id}"
      end

      private

      def base_path
        'https://slack.com/api/chat.postMessage'
      end

      def slack_team_id
        Settings.modules_appeals_api.lighthouse_team_id
      end

      def slack_channel_id
        Settings.modules_appeals_api.appeals_channel_id
      end
    end
  end
end
