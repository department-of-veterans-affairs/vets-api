# frozen_string_literal: true

require 'common/client/base'

module AppealsApi
  class SidekiqRetryNotifier
    API_PATH = 'https://slack.com/api/chat.postMessage'

    class << self
      # Params are expected to be in the Sidekiq Job Format (https://github.com/mperham/sidekiq/wiki/Job-Format),
      def notify!(params)
        Faraday.post(API_PATH, request_body(params), request_headers)
      end

      def message_text(params)
        msg = "ENVIRONMENT: #{Settings.vsp_environment}".dup
        msg << "\nThe sidekiq job #{params['class']} #{retries(params['retry_count'])}"
        msg << "\nJob Args: #{params['args']}" if params['args'].present?
        msg << "\nError Type: #{params['error_class']}"
        msg << "\nError Message:\n #{params['error_message']}"
        msg << "\n\nThis job failed at: #{Time.zone.at(params['failed_at'])}, and #{retried_at(params['retried_at'])}"
        msg
      end

      private

      def request_body(params)
        {
          text: message_text(params),
          channel: slack_channel_id
        }.to_json
      end

      def request_headers
        {
          'Content-type' => 'application/json; charset=utf-8',
          'Authorization' => "Bearer #{slack_api_token}"
        }
      end

      def retried_at(retried_time)
        return 'was not retried.' unless retried_time

        "was retried at: #{Time.zone.at(retried_time)}."
      end

      def retries(retry_count)
        retry_count = retry_count.presence&.to_i
        return 'threw an error.' unless retry_count

        "has hit #{retry_count + 1} retries."
      end

      def slack_channel_id
        Settings.modules_appeals_api.slack.appeals_channel_id
      end

      def slack_api_token
        Settings.modules_appeals_api.slack.api_key
      end
    end
  end
end
