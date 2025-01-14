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
        deleted_records = EvidenceSubmission.where(delete_date: ..DateTime.now).destroy_all
        StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_records.size)

        nil
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error('Lighthouse::EvidenceSubmissions::DeleteEvidenceSubmissionRecordsJob error: ', e.message)
      end
    end
  end
end
