# frozen_string_literal: true

module AppealsApi
  module Slack
    class ErrorRetryNotification
      def initialize(params)
        # Params are expected to be in the Sidekiq Job Format (https://github.com/mperham/sidekiq/wiki/Job-Format),
        @params = params
      end

      def message_text
        msg = "ENVIRONMENT: #{environment}".dup
        msg << "\nThe sidekiq job #{params['class']} #{retries(params['retry_count'])}"
        msg << "\nJob Args: #{params['args']}" if params['args'].present?
        msg << "\nError Type: #{params['error_class']}"
        msg << "\nError Message:\n #{params['error_message']}"
        msg << "\n\nThis job failed at: #{Time.zone.at(params['failed_at'])}, and #{retried_at(params['retried_at'])}"
        msg
      end

      private

      attr_accessor :params

      def retried_at(retried_time)
        return 'was not retried.' unless retried_time

        "was retried at: #{Time.zone.at(retried_time)}."
      end

      def retries(retry_count)
        retry_count = retry_count.presence&.to_i
        return 'threw an error.' unless retry_count

        "has hit #{retry_count + 1} retries."
      end

      def environment
        env = Settings.vsp_environment

        env_emoji = Messager::ENVIRONMENT_EMOJIS[env.to_sym]

        ":#{env_emoji}: #{env} :#{env_emoji}:"
      end
    end
  end
end
