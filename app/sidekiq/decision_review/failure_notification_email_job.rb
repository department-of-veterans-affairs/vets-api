# frozen_string_literal: true

require 'sidekiq'

module DecisionReview
  class FailureNotificationEmailJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 30.minutes

    SAVED_CLAIM_MODEL_TYPES = %w[
      SavedClaim::NoticeOfDisagreement
      SavedClaim::HigherLevelReview
      SavedClaim::SupplementalClaim
    ].freeze

    TEMPLATE_IDS = {
      'HLR' => Settings.vanotify.services.benefits_decision_review.template_id.higher_level_review_form_error_email,
      'NOD' => Settings.vanotify.services.benefits_decision_review.template_id.notice_of_disagreement_form_error_email,
      'SC' => Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email
    }.freeze

    ERROR_STATUS = 'error'

    STATSD_KEY_PREFIX = 'worker.decision_review.failure_notification_email'

    def perform
      return unless enabled? && (submissions.present? || submission_uploads.present?)

      send_form_emails
      send_evidence_emails

      nil
    end

    private

    def send_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)
      submissions.each do |submission|

        send_email_with_vanotify(submission, nil, submission.created_at)

        submission.update(failure_notification_sent_at: DateTime.now)
        record_successful_form_email_sent(submission)
      rescue => e
        record_failure_form_email_sent(submission, e)
      end
    end

    def send_evidence_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.processing_records", submission_uploads.size)
      submission_uploads.each do |upload|
        submission = upload.appeal_submission

        send_email_with_vanotify(submission, upload.attachment_filename, upload.created_at)

        upload.update(failure_notification_sent_at: DateTime.now)

        record_successful_evidence_email_sent(submission)
      rescue => e
        record_failure_evidence_email_sent(upload, e)
      end
    end

    def send_email_with_vanotify(submission, filename, created_at)
      email_address = submission.current_email
      personalisation = {
        first_name: submission.mpi_profile.given_names[0],
        filename: filename,
        date_submitted: created_at.strftime('%B %d, %Y')
      }
      template_id = TEMPLATE_IDS[submission.type_of_appeal]

      vanotify_service.send_email({ email_address:, template_id:, personalisation: })
    end

    def vanotify_service
      @service ||= ::VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
    end

    def errored_saved_claims
      @errored_saved_claims ||= ::SavedClaim.where(type: SAVED_CLAIM_MODEL_TYPES).where(delete_date: nil)
                                            .where('metadata LIKE ?', '%error%')
                                            .order(id: :asc)
    end

    def submissions
      @submissions ||= begin
        uuids = errored_saved_claims.select { |sc| JSON.parse(sc.metadata)['status'] == ERROR_STATUS }.pluck(:guid)
        ::AppealSubmission.where(submitted_appeal_uuid: uuids).failure_not_sent
      end
    end

    def submission_uploads
      @submission_uploads ||= begin
        uploads = errored_saved_claims.map { |sc| JSON.parse(sc.metadata)['uploads'] }
        ids = uploads.flatten.select { |upload| upload&.fetch('status') == ERROR_STATUS }.pluck('id')
        ::AppealSubmissionUpload.where(lighthouse_upload_id: ids).failure_not_sent
      end
    end

    def enabled?
      Flipper.enabled? :decision_review_failure_notification_email_job_enabled
    end

    def record_successful_form_email_sent(submission)
      metadata = { submission_uuid: submission.submitted_appeal_uuid, form_type: submission.type_of_appeal }
      Rails.logger.info('DecisionReview::FailureNotificationEmailJob form email sent', metadata)

      StatsD.increment("#{STATSD_KEY_PREFIX}.form.email_queued", tags: ["form_type:#{submission.type_of_appeal}"])
    end

    def record_failure_form_email_sent(submission, error)
      metadata = { submission_uuid: submission.submitted_appeal_uuid, message: error.message }
      Rails.logger.error('DecisionReview::FailureNotificationEmailJob form error', metadata)

      StatsD.increment("#{STATSD_KEY_PREFIX}.form.error", tags: ["form_type:#{submission.type_of_appeal}"])
    end

    def record_successful_evidence_email_sent(submission)
      metadata = { submission_uuid: submission.submitted_appeal_uuid, form_type: submission.type_of_appeal }
      Rails.logger.info('DecisionReview::FailureNotificationEmailJob evidence email sent', metadata)
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.email_queued", tags: ["form_type:#{submission.type_of_appeal}"])
    end

    def record_failure_evidence_email_sent(upload, error)
      submission = upload.appeal_submission
      submission_uuid = submission.submitted_appeal_uuid

      metadata = { lighthouse_upload_id: upload.lighthouse_upload_id, submission_uuid: , message: error.message }
      Rails.logger.error('DecisionReview::FailureNotificationEmailJob evidence error',
                         )
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.error", tags: ["form_type:#{submission.type_of_appeal}"])
    end
  end
end
