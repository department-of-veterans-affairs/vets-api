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

    APPEAL_TYPE_TO_SERVICE_MAP = {
      'HLR' => 'higher-level-review',
      'NOD' => 'board-appeal',
      'SC' => 'supplemental-claims'
    }.freeze

    ERROR_STATUS = 'error'

    STATSD_KEY_PREFIX = 'worker.decision_review.failure_notification_email'

    VANOTIFY_API_KEY = Settings.vanotify.services.benefits_decision_review.api_key

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
        secondary_forms_enabled? &&
        (submissions.present? || submission_uploads.present? || errored_secondary_forms.present?)
    end

    def vanotify_service
      @service ||= ::VaNotify::Service.new(VANOTIFY_API_KEY)
    end

    def vanotify_service_with_callback(submission, template_id)
      callback_options = {
        callback_klass: DecisionReviews::FormNotificationCallback.to_s,
        callback_metadata: {
          email_type: :error,
          service_name: APPEAL_TYPE_TO_SERVICE_MAP[submission.type_of_appeal],
          function: 'form submission',
          submitted_appeal_uuid: submission.submitted_appeal_uuid,
          email_template_id: template_id
        }
      }
      ::VaNotify::Service.new(
        Settings.vanotify.services.benefits_decision_review.api_key,
        callback_options
      )
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

    def send_email_with_vanotify_form_callback(submission, filename, created_at, template_id)
      email_address = submission.current_email_address
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename:,
        date_submitted: created_at.strftime('%B %d, %Y')
      }

      vanotify_service_with_callback = vanotify_service_with_callback(submission, template_id)
      vanotify_service_with_callback.send_email({ email_address:, template_id:, personalisation: })
    end

    def send_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)

      submissions.each do |submission|
        appeal_type = submission.type_of_appeal
        reference = "#{appeal_type}-form-#{submission.submitted_appeal_uuid}"
        email_template_id = DecisionReviews::V1::FORM_TEMPLATE_IDS[appeal_type]
        response = if form_callbacks_enabled?
                     send_email_with_vanotify_form_callback(submission, nil, submission.created_at,
                                                            email_template_id)
                   else
                     send_email_with_vanotify(submission, nil, submission.created_at,
                                              email_template_id, reference)
                   end

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
        template_id = DecisionReviews::V1::EVIDENCE_TEMPLATE_IDS[appeal_type]
        reference = "#{appeal_type}-evidence-#{upload.lighthouse_upload_id}"

        response = if evidence_callbacks_enabled?
                     send_email_with_vanotify_evidence_callback(submission, upload.masked_attachment_filename,
                                                                upload.created_at, 'evidence submission to lighthouse',
                                                                template_id)
                   else
                     send_email_with_vanotify(submission, upload.masked_attachment_filename, upload.created_at,
                                              template_id, reference)
                   end

        upload.update(failure_notification_sent_at: DateTime.now)

        record_evidence_email_send_successful(upload, response.id)
      rescue => e
        record_evidence_email_send_failure(upload, e)
      end
    end

    def send_email_with_vanotify_evidence_callback(submission, filename, created_at, function, template_id)
      email_address = submission.current_email_address
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename:,
        date_submitted: created_at.strftime('%B %d, %Y')
      }
      callback_options = {
        callback_klass: DecisionReviews::EvidenceNotificationCallback.name,
        callback_metadata: {
          email_type: :error,
          service_name: APPEAL_TYPE_TO_SERVICE_MAP[submission.type_of_appeal],
          function:,
          submitted_appeal_uuid: submission.submitted_appeal_uuid,
          email_template_id: template_id
        }
      }

      service = ::VaNotify::Service.new(VANOTIFY_API_KEY, callback_options)
      service.send_email({ email_address:, template_id:, personalisation: })
    end

    def send_secondary_form_emails
      StatsD.increment("#{STATSD_KEY_PREFIX}.secondary_forms.processing_records", errored_secondary_forms.size)
      errored_secondary_forms.each do |form|
        appeal_type = form.appeal_submission.type_of_appeal
        template_id = DecisionReviews::V1::SECONDARY_FORM_TEMPLATE_ID
        reference = "#{appeal_type}-secondary_form-#{form.guid}"
        response = if secondary_form_callbacks_enabled?
                     send_email_with_vanotify_evidence_callback(form.appeal_submission, nil, form.created_at,
                                                                'secondary form submission to lighthouse', template_id)
                   else
                     send_email_with_vanotify(form.appeal_submission, nil, form.created_at, template_id, reference)
                   end
        form.update(failure_notification_sent_at: DateTime.now)

        record_secondary_form_email_send_successful(form, response.id)
      rescue => e
        record_secondary_form_email_send_failure(form, e)
      end
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

    def secondary_forms_enabled?
      Flipper.enabled? :decision_review_notify_4142_failures
    end

    def form_callbacks_enabled?
      Flipper.enabled? :decision_review_notification_form_callbacks
    end

    def evidence_callbacks_enabled?
      Flipper.enabled? :decision_review_notification_evidence_callbacks
    end

    def secondary_form_callbacks_enabled?
      Flipper.enabled? :decision_review_notification_secondary_form_callbacks
    end
  end
end
