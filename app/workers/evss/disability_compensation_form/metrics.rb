# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Helper class that fires off StatsD metrics
    #
    # @param prefix [String] Will prefix all metric names
    #
    class Metrics
      def initialize(prefix)
        @prefix = prefix
      end

      # Increments a job try
      #
      def increment_try
        StatsD.increment("#{@prefix}.try")
      end

      # Increments a job success
      #
      def increment_success
        StatsD.increment("#{@prefix}.success")
      end

      # Increments a non retryable error with a tag for the specific error
      #
      def increment_non_retryable(error)
        StatsD.increment("#{@prefix}.non_retryable_error", tags: error_tags(error))
      end

      # Increments a retryable error with a tag for the specific error
      #
      def increment_retryable(error)
        StatsD.increment("#{@prefix}.retryable_error", tags: error_tags(error))
      end

      # Increments when a job has exhausted all its retries
      #
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
