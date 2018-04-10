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
    end
  end
end
