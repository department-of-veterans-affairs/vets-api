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

      StatsD.increment("#{STATSD_KEY_PREFIX}.form.processing_records", submissions.size)

      submissions.each do |submission|
        handle_form_email(submission)
      rescue => e
        Rails.logger.error('DecisionReview::FailureNotificationEmailJob form error',
                           { submission_uuid: submission.submitted_appeal_uuid, message: e.message })
        StatsD.increment("#{STATSD_KEY_PREFIX}.form.error", tags: ["form_type:#{submission.type_of_appeal}"])
      end

      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.processing_records", submission_uploads.size)

      submission_uploads.each do |upload|
        handle_upload_email(upload)
      rescue => e
        submission = upload.appeal_submission
        Rails.logger.error('DecisionReview::FailureNotificationEmailJob evidence error',
                           { lighthouse_upload_id: upload.lighthouse_upload_id,
                             submission_uuid: submission.submitted_appeal_uuid, message: e.message })
        StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.error", tags: ["form_type:#{submission.type_of_appeal}"])
      end

      nil
    end

    private

    def vanotify_service
      @service ||= ::VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
    end

    def errored_saved_claims
      @errored_saved_claims ||= ::SavedClaim.where(type: SAVED_CLAIM_MODEL_TYPES).where(delete_date: nil)
                                            .where('metadata LIKE ?', '%error%')
                                            .order(id: :asc)
    end

    def submissions
      guids = errored_saved_claims.select { |sc| JSON.parse(sc.metadata)['status'] == ERROR_STATUS }.pluck(:guid)

      @submissions ||= ::AppealSubmission.where(submitted_appeal_uuid: guids)
                                         .where(failure_notification_sent_at: nil)
                                         .order(id: :asc)
    end

    def submission_uploads
      guids = errored_saved_claims.map { |sc| JSON.parse(sc.metadata)['uploads'] }
                                  .flatten
                                  .select { |upload| upload&.fetch('status') == ERROR_STATUS }
                                  .pluck('id')

      @submission_uploads ||= ::AppealSubmissionUpload.where(lighthouse_upload_id: guids)
                                                      .where(failure_notification_sent_at: nil)
                                                      .order(id: :asc)
    end

    def handle_form_email(submission)
      email_address, personalisation = get_email_and_personalisation(submission.user_uuid)
      personalisation[:date_submitted] = submission.created_at.strftime('%B %d, %Y')

      vanotify_service.send_email({ email_address:, template_id: TEMPLATE_IDS[submission.type_of_appeal],
                                    personalisation: })

      submission.update(failure_notification_sent_at: DateTime.now)

      Rails.logger.info('DecisionReview::FailureNotificationEmailJob form email sent',
                        { submission_uuid: submission.submitted_appeal_uuid, form_type: submission.type_of_appeal })
      StatsD.increment("#{STATSD_KEY_PREFIX}.form.email_queued", tags: ["form_type:#{submission.type_of_appeal}"])
    end

    def handle_upload_email(upload)
      submission = upload.appeal_submission

      email_address, personalisation = get_email_and_personalisation(submission.user_uuid, upload)
      personalisation[:date_submitted] = upload.created_at.strftime('%B %d, %Y')

      vanotify_service.send_email({ email_address:,
                                    template_id: TEMPLATE_IDS[upload.appeal_submission.type_of_appeal],
                                    personalisation: })
      upload.update(failure_notification_sent_at: DateTime.now)

      Rails.logger.info('DecisionReview::FailureNotificationEmailJob evidence email sent',
                        { submission_uuid: submission.submitted_appeal_uuid, form_type: submission.type_of_appeal })
      StatsD.increment("#{STATSD_KEY_PREFIX}.evidence.email_queued", tags: ["form_type:#{submission.type_of_appeal}"])
    end

    def get_email_and_personalisation(user_uuid, upload = nil)
      raise 'Missing user uuid' if user_uuid.nil?

      mpi_profile = get_mpi_profile(user_uuid)
      raise 'Failed to fetch MPI profile' if mpi_profile.nil?

      personalisation = {
        first_name: mpi_profile.given_names[0],
        filename: get_filename(upload)
      }

      [current_email(mpi_profile), personalisation]
    end

    def get_mpi_profile(user_uuid)
      service = ::MPI::Service.new
      idme_profile = service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'idme')&.profile
      logingov_profile = service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'logingov')&.profile
      idme_profile || logingov_profile
    end

    def current_email(mpi_profile)
      va_profile = ::VAProfile::ContactInformation::Service.get_person(mpi_profile.vet360_id.to_s)&.person
      raise 'Failed to fetch VA profile' if va_profile.nil?

      current_emails = va_profile.emails.select { |email| email.effective_end_date.nil? }
      email = current_emails.first&.email_address
      raise 'Failed to retrieve email' if email.nil?

      email
    end

    def get_filename(upload)
      return nil if upload.nil?

      guid = upload.decision_review_evidence_attachment_guid
      form_attachment = FormAttachment.find_by(guid:)
      raise "FormAttachment guid='#{guid}' not found" if form_attachment.nil?

      JSON.parse(form_attachment.file_data)['filename'].gsub(/(?<=.{3})[^_-](?=.{6})/, '*')
    end

    def enabled?
      Flipper.enabled? :decision_review_failure_notification_email_job_enabled
    end
  end
end
