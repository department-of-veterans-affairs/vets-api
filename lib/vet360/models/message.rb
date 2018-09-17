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

      # Converts a decoded JSON response from Vet360 to an instance of the Message model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Message] the model built from the response body
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
