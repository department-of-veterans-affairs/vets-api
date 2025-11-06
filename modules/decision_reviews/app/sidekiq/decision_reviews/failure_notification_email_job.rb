# frozen_string_literal: true

require 'sidekiq'
require 'decision_reviews/v1/constants'
require 'decision_reviews/notification_callbacks/form_notification_callback'
require 'decision_reviews/notification_callbacks/evidence_notification_callback'

module DecisionReviews
  class FailureNotificationEmailJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 30.minutes

    SAVED_CLAIM_MODEL_TYPES = %w[
      SavedClaim::NoticeOfDisagreement
      SavedClaim::HigherLevelReview
      SavedClaim::SupplementalClaim
    ].freeze

    ERROR_STATUS = 'error'

    STATSD_KEY_PREFIX = 'worker.decision_review.failure_notification_email'

    VANOTIFY_API_KEY = Settings.vanotify.services.benefits_decision_review.api_key

    def perform
      return unless should_perform?

      send_form_emails
      send_evidence_emails
      send_secondary_form_emails

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
        (
          submissions.present? ||
          submission_uploads.present? ||
          errored_secondary_forms.present? ||
          permanently_errored_secondary_forms.present?
        )
    end

    def get_callback_config(email_type, appeal_type)
      case email_type
      when :form
        [DecisionReviews::FormNotificationCallback, 'form submission', DecisionReviews::V1::FORM_TEMPLATE_IDS[appeal_type]]
      when :evidence
        [DecisionReviews::EvidenceNotificationCallback, 'evidence submission to lighthouse', DecisionReviews::V1::EVIDENCE_TEMPLATE_IDS[appeal_type]]
      when :secondary_form
        [DecisionReviews::EvidenceNotificationCallback, 'secondary form submission to lighthouse', DecisionReviews::V1::SECONDARY_FORM_TEMPLATE_ID]
      end
    end

    def vanotify_service_with_callback(submission, email_type, reference)
      appeal_type = submission.type_of_appeal
      callback_klass, function, email_template_id = get_callback_config(email_type, appeal_type)
      service_name = DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]

      callback_options = {
        callback_klass: callback_klass.to_s,
        callback_metadata: {
          email_type: :error,
          service_name:,
          function:,
          submitted_appeal_uuid: submission.submitted_appeal_uuid,
          email_template_id:,
          reference:,
          statsd_tags: ["service:#{service_name}", "function:#{function}"]
        }
      }
      ::VaNotify::Service.new(VANOTIFY_API_KEY, callback_options)
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

    # New method to fetch SecondaryAppealForm records that have an error status with a final status: true
    def permanently_errored_secondary_forms
      return [] unless final_status_secondary_form_failure_notifications_enabled?

      @permanently_errored_secondary_forms ||= SecondaryAppealForm.with_permanent_error.order(id: :asc)
    end

    # Legacy method to fetch SecondaryAppealForm records that have an error status without a final status
    def errored_secondary_forms
      @errored_secondary_forms ||= SecondaryAppealForm.needs_failure_notification.order(id: :asc)
    end

    def send_email_with_vanotify_callback(submission, email_type, filename, created_at, reference)
      email_address = submission.current_email_address
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename:,
        date_submitted: created_at.strftime('%B %d, %Y')
      }

      _, _, template_id = get_callback_config(email_type, submission.type_of_appeal)

      vanotify_service = vanotify_service_with_callback(submission, email_type, reference)
      vanotify_service.send_email({ email_address:, template_id:, personalisation: })
    end

    def send_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)

      submissions.each do |submission|
        reference = "#{submission.type_of_appeal}-form-#{submission.submitted_appeal_uuid}"

        response = send_email_with_vanotify_callback(
          submission,
          :form,
          nil,
          submission.created_at,
          reference
        )

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
        reference = "#{submission.type_of_appeal}-evidence-#{upload.lighthouse_upload_id}"

        response = send_email_with_vanotify_callback(submission, :evidence, upload.masked_attachment_filename,
                                                     upload.created_at, reference)

        upload.update(failure_notification_sent_at: DateTime.now)

        record_evidence_email_send_successful(upload, response.id)
      rescue => e
        record_evidence_email_send_failure(upload, e)
      end
    end

    def send_secondary_form_emails
      # Branch to separate implementations for clean feature flag removal
      if final_status_secondary_form_failure_notifications_enabled?
        send_secondary_form_emails_enhanced
      else
        send_secondary_form_emails_legacy
      end
    end

    def send_secondary_form_emails_enhanced
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_forms.processing_records",
                       permanently_errored_secondary_forms.size)

      permanently_errored_secondary_forms.each do |form|
        send_secondary_form_email(form)
      end
    end

    def send_secondary_form_emails_legacy
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_forms.processing_records", errored_secondary_forms.size)

      errored_secondary_forms.each do |form|
        send_secondary_form_email(form)
      end
    end

    def send_secondary_form_email(form)
      appeal_type = form.appeal_submission.type_of_appeal
      reference = "#{appeal_type}-secondary_form-#{form.guid}"

      response = send_email_with_vanotify_callback(form.appeal_submission, :secondary_form, nil,
                                                   form.created_at, reference)

      form.update(failure_notification_sent_at: DateTime.now)

      record_secondary_form_email_send_successful(form, response.id)
    rescue => e
      record_secondary_form_email_send_failure(form, e)
    end

    def record_form_email_send_successful(submission, notification_id)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid, appeal_type:, notification_id: }
      Rails.logger.info('DecisionReviews::FailureNotificationEmailJob form email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.email_queued", tags: ["appeal_type:#{appeal_type}"])
    end

    def record_form_email_send_failure(submission, e)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid, appeal_type:, message: e.message }
      Rails.logger.error('DecisionReviews::FailureNotificationEmailJob form error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.error", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}",
              'function: form submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)
    end

    def record_secondary_form_email_send_successful(secondary_form, notification_id)
      submission = secondary_form.appeal_submission
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 lighthouse_upload_id: secondary_form.guid,
                 appeal_type:,
                 notification_id: }
      Rails.logger.info('DecisionReviews::FailureNotificationEmailJob secondary form email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_form.email_queued", tags: ["appeal_type:#{appeal_type}"])
    end

    def record_secondary_form_email_send_failure(secondary_form, e)
      submission = secondary_form.appeal_submission
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 lighthouse_upload_id: secondary_form.guid,
                 appeal_type:,
                 message: e.message }
      Rails.logger.error('DecisionReviews::FailureNotificationEmailJob secondary form error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_form.error", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}",
              'function: secondary form submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)
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
      Rails.logger.info('DecisionReviews::FailureNotificationEmailJob evidence email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.email_queued", tags: ["appeal_type:#{appeal_type}"])
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
      Rails.logger.error('DecisionReviews::FailureNotificationEmailJob evidence error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.error", tags: ["appeal_type:#{appeal_type}"])

      tags = ["service:#{DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}",
              'function: evidence submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)
    end

    def enabled?
      Flipper.enabled? :decision_review_failure_notification_email_job_enabled
    end

    # Feature flag helpers for clean removal later
    def final_status_secondary_form_failure_notifications_enabled?
      Flipper.enabled?(:decision_review_final_status_secondary_form_failure_notifications)
    end
  end
end
