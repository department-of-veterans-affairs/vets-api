# frozen_string_literal: true

require 'common/client/base'

module VBADocuments
  module Slack
    class Messenger
      ALERT_URL = Settings.vba_documents.slack.default_alert_url
      ENVIRONMENT_EMOJIS = { production: 'rotating_light', sandbox: 'rocket', staging: 'construction',
                             development: 'brain' }.freeze

      def initialize(params)
        @params = params
      end

      def notify!
        Faraday.post(ALERT_URL, request_body, request_headers)
      end

      private

      attr_reader :params

      def notification
        VBADocuments::Slack::HashNotification.new(params)
      end

      def request_body
        { text: notification.message_text }.to_json
      end

      def request_headers
        { 'Content-type' => 'application/json; charset=utf-8' }
      end
    end
  end
end
