# frozen_string_literal: true

require 'common/client/base'

module AppealsApi
  class SidekiqRetryNotifier
    WEBHOOK_URL = "https://hooks.slack.com/services/#{Settings.modules_appeals_api.slack_sidekiq_webhook_creds}"

    def self.notify!(params)
      Faraday.post(WEBHOOK_URL, message_text(params))
    end

    def self.message_text(params)
      {
        text: ''"
        The sidekiq job #{params['class']} has hit #{params['retry_count']} retries.
        \nError Type: #{params['error_class']} \n Error Message: \n #{params['error_message']} \n\n
This job failed at: #{Time.zone.at(params['failed_at'])}, and was retried at: #{Time.zone.at(params['retried_at'])}
        "''
      }.to_json
    end
  end
end
