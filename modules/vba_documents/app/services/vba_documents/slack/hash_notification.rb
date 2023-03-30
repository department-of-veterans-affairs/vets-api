# frozen_string_literal: true

module VBADocuments
  module Slack
    class HashNotification
      def initialize(params)
        # Params are expected to be in the Sidekiq Job Format (https://github.com/mperham/sidekiq/wiki/Job-Format),
        @params = params
      end

      def message_text
        msg = "ENVIRONMENT: #{environment}".dup

        params.each do |k, v|
          msg << "\n#{k.to_s.upcase} : #{v}"
        end

        msg
      end

      private

      attr_accessor :params

      def environment
        env = Settings.vsp_environment

        env_emoji = Messenger::ENVIRONMENT_EMOJIS[env.to_sym]

        ":#{env_emoji}: #{env} :#{env_emoji}:"
      end
    end
  end
end
