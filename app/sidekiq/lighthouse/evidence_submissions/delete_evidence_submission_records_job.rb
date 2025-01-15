# frozen_string_literal: true

require 'sidekiq'

module Lighthouse
  module EvidenceSubmissions
    class DeleteEvidenceSubmissionRecordsJob
      include Sidekiq::Job

      # No need to retry since the schedule will run this periodically
      sidekiq_options retry: false

      STATSD_KEY_PREFIX = 'worker.cst.delete_evidence_submission_records'

      def perform
        record_count = EvidenceSubmission.all.count
        deleted_records = EvidenceSubmission.where(delete_date: ..DateTime.now).destroy_all

        StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_records.size)
        Rails.logger.info("#{self.class} deleted #{deleted_records.size} of #{record_count} EvidenceSubmission records")

        nil
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error("#{self.class} error: ", e.message)
      end
    end
  end
end
