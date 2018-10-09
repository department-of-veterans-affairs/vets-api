# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Metrics
      def initialize(prefix, job_id)
        @prefix = prefix
        @job_id = job_id
      end

      def increment_try
        StatsD.increment("#{@prefix}.try", tags: ["job_id:#{@job_id}"])
      end

      def increment_success
        StatsD.increment("#{@prefix}.success", tags: ["job_id:#{@job_id}"])
      end

      def increment_non_retryable(error)
        tags = statsd_tags(error)
        StatsD.increment("#{@prefix}.non_retryable_error", tags: tags)
      end

      def increment_retryable(error)
        tags = statsd_tags(error)
        StatsD.increment("#{@prefix}.retryable_error", tags: tags)
      end

      def increment_exhausted
        StatsD.increment("#{@prefix}.exhausted", tags: ["job_id:#{@job_id}"])
      end

      private

      def statsd_tags(error)
        tags = ["error:#{error.class}"]
        tags << "job_id:#{@job_id}"
        tags << "status:#{error.status_code}" if error.try(:status_code)
        tags << "message:#{error.message}" if error.try(:message)
        tags
      end
    end
  end
end
