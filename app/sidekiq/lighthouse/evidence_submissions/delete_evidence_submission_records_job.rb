# frozen_string_literal: true

require 'sidekiq'
require 'lighthouse/benefits_documents/constants'

module Lighthouse
  module EvidenceSubmissions
    class DeleteEvidenceSubmissionRecordsJob
      include Sidekiq::Job

      # No need to retry since the schedule will run this periodically
      sidekiq_options retry: 0

      STATSD_KEY_PREFIX = 'worker.cst.delete_evidence_submission_records'

      def perform
        record_count = EvidenceSubmission.all.count

        # Delete successful uploads that have reached their retention period
        deleted_success_records = delete_records_by_status(
          BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]
        )

        # Delete failed uploads that have reached their retention period
        # (only those with delete_date set, meaning notification email was successfully sent)
        deleted_failed_records = delete_records_by_status(
          BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
        )

        total_deleted = deleted_success_records.size + deleted_failed_records.size

        StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_success_records.size, tags: ['status:success'])
        StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_failed_records.size, tags: ['status:failed'])
        Rails.logger.info(
          "#{self.class} deleted #{total_deleted} of #{record_count} EvidenceSubmission records " \
          "(#{deleted_success_records.size} success, #{deleted_failed_records.size} failed)"
        )

        nil
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error("#{self.class} error: ", e.message)
      end

      private

      def delete_records_by_status(status)
        EvidenceSubmission.where(
          delete_date: ..DateTime.current,
          upload_status: status
        ).destroy_all
      end
    end
  end
end
