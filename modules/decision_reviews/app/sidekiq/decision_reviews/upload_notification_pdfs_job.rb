# frozen_string_literal: true

require 'decision_reviews/notification_pdf_uploader'

module DecisionReviews
  # Background job to generate and upload notification email PDFs to VBMS
  # Processes DecisionReviewNotificationAuditLogs that haven't been uploaded yet
  # Runs daily after FailureNotificationEmailJob to upload PDFs for all delivered notifications
  class UploadNotificationPdfsJob
    include Sidekiq::Job

    sidekiq_options retry: 3

    STATSD_KEY_PREFIX = 'worker.decision_reviews.upload_notification_email_pdfs'
    MAX_RETRY_ATTEMPTS = 3
    # Only process records with final email delivery statuses
    FINAL_STATUSES = %w[delivered permanent-failure].freeze
    # Only process records created on or after this date (avoid uploading historical PDFs)
    CUTOFF_DATE = Date.new(2025, 12, 12).freeze

    def perform
      return unless enabled?

      StatsD.increment("#{STATSD_KEY_PREFIX}.started")

      audit_logs = fetch_pending_uploads

      if audit_logs.empty?
        StatsD.increment("#{STATSD_KEY_PREFIX}.no_pending_uploads")
        return
      end

      process_uploads(audit_logs)

      nil
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error('DecisionReviews::UploadNotificationPdfsJob error', error: e.message)
      raise
    end

    private

    def enabled?
      Flipper.enabled?(:decision_review_upload_notification_pdfs_enabled)
    end

    # NOTE: This query is optimized for current volume (~300 records/month).
    # Consider adding a composite index if volume significantly increases.
    def fetch_pending_uploads
      DecisionReviewNotificationAuditLog
        .where(pdf_uploaded_at: nil)
        .where(status: FINAL_STATUSES)
        .where('pdf_upload_attempt_count IS NULL OR pdf_upload_attempt_count < ?', MAX_RETRY_ATTEMPTS)
        .where('created_at >= ?', CUTOFF_DATE)
        .order(created_at: :asc)
    end

    def process_uploads(audit_logs)
      success_count = 0
      failure_count = 0

      audit_logs.each do |audit_log|
        upload_notification_pdf(audit_log)
        success_count += 1
      rescue => e
        failure_count += 1
        log_upload_failure(audit_log, e)
      end

      log_results(audit_logs.count, success_count, failure_count)
    end

    def upload_notification_pdf(audit_log)
      uploader = NotificationPdfUploader.new(audit_log)
      file_uuid = uploader.upload_to_vbms

      StatsD.increment("#{STATSD_KEY_PREFIX}.upload_success")
      Rails.logger.info('DecisionReviews::UploadNotificationPdfsJob uploaded PDF',
                        notification_id: audit_log.notification_id,
                        reference: audit_log.reference,
                        file_uuid:)
    end

    def log_upload_failure(audit_log, error)
      StatsD.increment("#{STATSD_KEY_PREFIX}.upload_failure")
      Rails.logger.error('DecisionReviews::UploadNotificationPdfsJob upload failed',
                         notification_id: audit_log.notification_id,
                         reference: audit_log.reference,
                         error: error.message)
    end

    def log_results(total_count, success_count, failure_count)
      StatsD.gauge("#{STATSD_KEY_PREFIX}.total_count", total_count)
      StatsD.gauge("#{STATSD_KEY_PREFIX}.success_count", success_count)
      StatsD.gauge("#{STATSD_KEY_PREFIX}.failure_count", failure_count)

      Rails.logger.info('DecisionReviews::UploadNotificationPdfsJob complete',
                        total: total_count,
                        success: success_count,
                        failures: failure_count)
    end
  end
end
