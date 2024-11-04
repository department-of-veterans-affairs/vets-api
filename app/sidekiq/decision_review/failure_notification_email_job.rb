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

    SECONDARY_FORM_TEMPLATE_ID = TEMPLATE_IDS.supplemental_claim_secondary_form_error_email

    APPEAL_TYPE_TO_SERVICE_MAP = {
      'HLR' => 'higher-level-review',
      'NOD' => 'board-appeal',
      'SC' => 'supplemental-claims'
    }.freeze

    ERROR_STATUS = 'error'

    STATSD_KEY_PREFIX = 'worker.decision_review.failure_notification_email'

    def perform
      return unless should_perform?

      send_form_emails
      send_evidence_emails
      send_secondary_form_emails if secondary_forms_enabled?

      nil
    end

    private

    def should_perform?
      perform_form_and_evidence || perform_all
    end

    def perform_form_and_evidence
      enabled? && (submissions.present? || submission_uploads.present?)
    end

    def perform_all
      enabled? &&
        (secondary_forms_enabled? &&
        (submissions.present? || submission_uploads.present? || errored_secondary_forms.present?))
    end

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

    def errored_secondary_forms
      @errored_secondary_forms ||= SecondaryAppealForm.needs_failure_notification.order(id: :asc)
    end

    def send_email_with_vanotify(submission, filename, created_at, template_id, reference)
      email_address = submission.current_email_address
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename:,
        date_submitted: created_at.strftime('%B %d, %Y')
      }

      vanotify_service.send_email({ email_address:, template_id:, personalisation:, reference: })
    end

    def send_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)

      submissions.each do |submission|
        appeal_type = submission.type_of_appeal
        reference = "#{appeal_type}-form-#{submission.submitted_appeal_uuid}"

        response = send_email_with_vanotify(submission, nil, submission.created_at, FORM_TEMPLATE_IDS[appeal_type],
                                            reference)
        submission.update(failure_notification_sent_at: DateTime.now)

        record_form_email_send_successful(submission, response.id)
      rescue => e
        record_form_email_send_failure(submission, e)
      end
    end

    def send_evidence_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.processing_records", submission_uploads.size)

      submission_uploads.each do |upload|
        submission = upload.appeal_submission
        appeal_type = submission.type_of_appeal
        reference = "#{appeal_type}-evidence-#{upload.lighthouse_upload_id}"

        response = send_email_with_vanotify(submission, upload.masked_attachment_filename, upload.created_at,
                                            EVIDENCE_TEMPLATE_IDS[appeal_type], reference)
        upload.update(failure_notification_sent_at: DateTime.now)

        record_evidence_email_send_successful(upload, response.id)
      rescue => e
        record_evidence_email_send_failure(upload, e)
      end
    end

    def send_secondary_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_forms.processing_records", errored_secondary_forms.size)
      errored_secondary_forms.each do |form|
        appeal_type = form.appeal_submission.type_of_appeal
        reference = "#{appeal_type}-secondary_form-#{form.guid}"
        response = send_email_with_vanotify(form.appeal_submission,
                                            nil,
                                            form.created_at,
                                            SECONDARY_FORM_TEMPLATE_ID,
                                            reference)
        form.update(failure_notification_sent_at: DateTime.now)

        record_secondary_form_email_send_successful(form, response.id)
      rescue => e
        record_secondary_form_email_send_failure(form, e)
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

    def record_secondary_form_email_send_successful(secondary_form, notification_id)
      submission = secondary_form.appeal_submission
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 lighthouse_upload_id: secondary_form.guid,
                 appeal_type:,
                 notification_id: }
      Rails.logger.info('DecisionReview::FailureNotificationEmailJob secondary form email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_form.email_queued", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}", 'function: secondary form submission to Lighthouse']
      StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
    end

    def record_secondary_form_email_send_failure(secondary_form, e)
      submission = secondary_form.appeal_submission
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 lighthouse_upload_id: secondary_form.guid,
                 appeal_type:,
                 message: e.message }
      Rails.logger.error('DecisionReview::FailureNotificationEmailJob secondary form error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_form.error", tags: ["appeal_type:#{appeal_type}"])
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

    def secondary_forms_enabled?
      Flipper.enabled? :decision_review_notify_4142_failures
    end
  end
end
