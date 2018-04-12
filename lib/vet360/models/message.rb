# frozen_string_literal: true

module Vet360
  module Models
    class Message < Base
      SEVERITY_LEVELS = %w[
        INFO
        WARN
        ERROR
        FATAL
      ].freeze

      attribute :code, String
      attribute :key, String
      attribute :retryable, Boolean
      attribute :severity, String
      attribute :text, String

      validates(
        :severity,
        presence: true,
        inclusion: { in: SEVERITY_LEVELS }
      )

      def self.from_response(body)
        body.map do |msg|
          Vet360::Models::Message.new(
            code: msg['code'],
            key: msg['key'],
            retryable: msg['potentially_self_correcting_on_retry'],
            severity: msg['severity'],
            text: msg['text']
          )
        end
      end
    end
  end
end
