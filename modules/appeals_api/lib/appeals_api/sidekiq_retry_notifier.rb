# frozen_string_literal

require 'common/client/base'

module AppealsApi
  class SidekiqRetryNotifier

    WEBHOOK_URL = 'https://hooks.slack.com/services/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'

    def self.notify!(params)
      Faraday.post(WEBHOOK_URL, message_text(params))
    end

    private

    def self.message_text(params)
      {
        text: "The sidekiq job #{params['class']} has hit #{params['retry_count']} retries.\nError Type: #{params['error_class']} \n Error Message: \n #{params['error_message']} \n\nThis job failed at: #{Time.at(params['failed_at'])}, and was retried at: #{Time.at(params['retried_at'])}"
      }.to_json
    end
  end
end
