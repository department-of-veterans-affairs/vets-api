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

    TEMPLATE_IDS = Settings.vanotify.services.benefits_decision_review.template_id

    FORM_TEMPLATE_IDS = {
      'HLR' => TEMPLATE_IDS.higher_level_review_form_error_email,
      'NOD' => TEMPLATE_IDS.notice_of_disagreement_form_error_email,
      'SC' => TEMPLATE_IDS.supplemental_claim_form_error_email
    }.freeze

    EVIDENCE_TEMPLATE_IDS = {
      'NOD' => TEMPLATE_IDS.notice_of_disagreement_evidence_error_email,
      'SC' => TEMPLATE_IDS.supplemental_claim_evidence_error_email
    }.freeze

    APPEAL_TYPE_TO_SERVICE_MAP = {
      'HLR' => 'higher-level-review',
      'NOD' => 'board-appeal',
      'SC' => 'supplemental-claims'
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

    def vanotify_service
      @service ||= ::VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
    end

    # Fetches SavedClaim records for DecisionReview that have an error status for the form or any evidence attachments
    def errored_saved_claims
      @errored_saved_claims ||= ::SavedClaim.where(type: SAVED_CLAIM_MODEL_TYPES)
                                            .where(delete_date: nil)
                                            .where('metadata LIKE ?', '%error%')
                                            .order(id: :asc)
    end

    def submissions
      @submissions ||= begin
        guids = errored_saved_claims.select { |sc| JSON.parse(sc.metadata)['status'] == ERROR_STATUS }.pluck(:guid)
        ::AppealSubmission.where(submitted_appeal_uuid: guids).failure_not_sent
      end
    end

    def submission_uploads
      @submission_uploads ||= begin
        uploads = errored_saved_claims.map { |sc| JSON.parse(sc.metadata)['uploads'] }
        ids = uploads.flatten.select { |upload| upload&.fetch('status') == ERROR_STATUS }.pluck('id')

        ::AppealSubmissionUpload.where(lighthouse_upload_id: ids).failure_not_sent
      end
    end

    def send_email_with_vanotify(submission, filename, created_at)
      email_address = submission.current_email
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename:,
        date_submitted: created_at.strftime('%B %d, %Y')
      }

      appeal_type = submission.type_of_appeal
      template_id = filename.nil? ? FORM_TEMPLATE_IDS[appeal_type] : EVIDENCE_TEMPLATE_IDS[appeal_type]
      vanotify_service.send_email({ email_address:, template_id:, personalisation: })
    end

    def send_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)

      submissions.each do |submission|
        response = send_email_with_vanotify(submission, nil, submission.created_at)
        submission.update(failure_notification_sent_at: DateTime.now)

        record_form_email_send_successful(submission, response.id)
      rescue => e
        record_form_email_send_failure(submission, e)
      end
    end

    def send_evidence_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.processing_records", submission_uploads.size)

      submission_uploads.each do |upload|
        response = send_email_with_vanotify(upload.appeal_submission,
                                            upload.masked_attachment_filename,
                                            upload.created_at)
        upload.update(failure_notification_sent_at: DateTime.now)

        record_evidence_email_send_successful(upload, response.id)
      rescue => e
        record_evidence_email_send_failure(upload, e)
      end
    end

    def record_form_email_send_successful(submission, notification_id)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid, appeal_type:, notification_id: }
      Rails.logger.info('DecisionReview::FailureNotificationEmailJob form email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.email_queued", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}", 'function: form submission to Lighthouse']
      StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
    end

    def record_form_email_send_failure(submission, e)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid, appeal_type:, message: e.message }
      Rails.logger.error('DecisionReview::FailureNotificationEmailJob form error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.error", tags: ["appeal_type:#{appeal_type}"])
    end

    def record_evidence_email_send_successful(upload, notification_id)
      submission = upload.appeal_submission
      appeal_type = submission.type_of_appeal
      params = {
        submitted_appeal_uuid: submission.submitted_appeal_uuid,
        lighthouse_upload_id: upload.lighthouse_upload_id,
        appeal_type:,
        notification_id:
      }
      Rails.logger.info('DecisionReview::FailureNotificationEmailJob evidence email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.email_queued", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}", 'function: evidence submission to Lighthouse']
      StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
    end

    def record_evidence_email_send_failure(upload, e)
      submission = upload.appeal_submission
      appeal_type = submission.type_of_appeal
      params = {
        submitted_appeal_uuid: submission.submitted_appeal_uuid,
        lighthouse_upload_id: upload.lighthouse_upload_id,
        appeal_type:,
        message: e.message
      }
      Rails.logger.error('DecisionReview::FailureNotificationEmailJob evidence error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.error", tags: ["appeal_type:#{appeal_type}"])
    end

    def enabled?
      Flipper.enabled? :decision_review_failure_notification_email_job_enabled
    end
  end
end
