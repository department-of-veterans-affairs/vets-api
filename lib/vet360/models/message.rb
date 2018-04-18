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

      def self.build_from(body)
        Vet360::Models::Message.new(
          code: body['code'],
          key: body['key'],
          retryable: body['potentially_self_correcting_on_retry'],
          severity: body['severity'],
          text: body['text']
        )
      end
    end
  end
end
