# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Metrics
      def initialize(prefix)
        @prefix = prefix
      end

      def increment_try
        StatsD.increment("#{@prefix}.try")
      end

      def increment_success
        StatsD.increment("#{@prefix}.success")
      end

      def increment_non_retryable(error)
        StatsD.increment("#{@prefix}.non_retryable_error", tags: error_tags(error))
      end

      def increment_retryable(error)
        StatsD.increment("#{@prefix}.retryable_error", tags: error_tags(error))
      end

      def increment_exhausted
        StatsD.increment("#{@prefix}.exhausted")
      end

      private

      def error_tags(error)
        tags = ["error:#{error.class}"]
        tags << "status:#{error.status_code}" if error.try(:status_code)
        tags << "message:#{error.message}" if error.try(:message)
        tags
      end
    end
  end
end
