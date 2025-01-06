# frozen_string_literal: true

require 'decision_reviews/v1/service'
require 'decision_reviews/v1/logging_utils'

module DecisionReviews
  class SubmitUpload
    include Sidekiq::Job
    include DecisionReviews::V1::LoggingUtils

    STATSD_KEY_PREFIX = 'worker.decision_review.submit_upload'

    # Increasing to 17 retries, approximately 3 days, for ~39 hour COLA maintenance
    sidekiq_options retry: 17

    sidekiq_retries_exhausted do |msg, _ex|
      error_message = msg['error_message']
      message = 'DecisionReviews::SubmitUpload retries exhausted'
      job_id = msg['jid']
      appeal_submission_upload_id = msg['args'].first

      upload = AppealSubmissionUpload.find(appeal_submission_upload_id)
      submission = upload.appeal_submission

      ::Rails.logger.error({ error_message:, message:, appeal_submission_upload_id:, job_id: })
      StatsD.increment("#{STATSD_KEY_PREFIX}.permanent_error")

      begin
        response = send_notification_email(upload, submission)
        upload.update(failure_notification_sent_at: DateTime.now)

        record_email_send_successful(upload, submission, response.id)
      rescue => e
        record_email_send_failure(upload, submission, e)
      end
    end

    # Make a request to Lighthouse to get the URL where we can upload the file,
    # then get the file from S3 and send it to Lighthouse
    #
    # @param appeal_submission_upload_id [String] UUID in response from Lighthouse upload
    def perform(appeal_submission_upload_id)
      appeal_submission_upload = AppealSubmissionUpload.find(appeal_submission_upload_id)
      appeal_submission = appeal_submission_upload.appeal_submission
      form_attachment = appeal_submission_upload.decision_review_evidence_attachment
      sanitized_file = get_sanitized_file!(form_attachment:)
      file_number_or_ssn = JSON.parse(appeal_submission.upload_metadata)['fileNumber']

      lh_upload_id = case appeal_submission.type_of_appeal
                     when 'NOD'
                       handle_notice_of_disagreement(appeal_submission_upload, file_number_or_ssn, sanitized_file)
                     when 'SC'
                       handle_supplemental_claim(appeal_submission_upload, file_number_or_ssn, sanitized_file)
                     else
                       raise "Unknown appeal type (#{type})"
                     end.body.dig('data', 'id')
      appeal_submission_upload.update!(lighthouse_upload_id: lh_upload_id)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      raise e
    end

    private

    # Get the sanitized file from S3
    #
    # @param form_attachment [DecisionReviewEvidenceAttachment]
    # @return [CarrierWave::SanitizedFile] The sanitized file from S3
    def get_sanitized_file!(form_attachment:)
      appeal_submission_upload = form_attachment.appeal_submission_upload
      appeal_submission = appeal_submission_upload.appeal_submission
      # For now, I'm limiting our new `log_formatted` style of logging to the NOD form. In the near future, we will
      # expand this style of logging to every Decision Review form.
      form_id = appeal_submission.type_of_appeal == 'NOD' ? '10182' : '995'
      log_params = sanitized_file_log_params(appeal_submission, appeal_submission_upload, form_attachment, form_id)

      begin
        sanitized_file = form_attachment.get_file
        log_formatted(**log_params.merge(is_success: true))
        sanitized_file
      rescue => e
        log_formatted(**log_params.merge(is_success: false, response_error: e))
        raise e
      end
    end

    # Get the sanitized file from S3
    #
    # @param appeal_submission [AppealSubmission]
    # @param appeal_submission_upload [AppealSubmissionUpload]
    # @param form_attachment [DecisionReviewEvidenceAttachment]
    # @return [Hash] log params for get_sanitized_file! logging
    def sanitized_file_log_params(appeal_submission, appeal_submission_upload, form_attachment, form_id)
      {
        key: :evidence_upload_retrieval,
        form_id:,
        user_uuid: appeal_submission.user_uuid,
        upstream_system: 'AWS S3',
        params: {
          appeal_submission_upload_id: appeal_submission_upload.id,
          form_attachment_id: form_attachment.id
        }
      }
    end

    def get_dr_svc
      DecisionReviews::V1::Service.new
    end

    # Handle notice of disagreement appeal type. Make a request to Lighthouse to get the URL where we can upload the
    # file, then get the file from S3 and send it to Lighthouse
    #
    # @param appeal_submission_upload [AppealSubmissionUpload]
    # @param file_number_or_ssn [String] Veteran's SSN or File #
    # @param sanitized_file [CarrierWave::SanitizedFile] The sanitized file from S3
    # @return [Faraday::Env] The response from Lighthouse
    def handle_notice_of_disagreement(appeal_submission_upload, file_number_or_ssn, sanitized_file)
      Sentry.set_tags(source: '10182-board-appeal')
      appeal_submission = appeal_submission_upload.appeal_submission
      upload_url_response = get_dr_svc.get_notice_of_disagreement_upload_url(
        nod_uuid: appeal_submission.submitted_appeal_uuid,
        file_number: file_number_or_ssn,
        user_uuid: appeal_submission.user_uuid,
        appeal_submission_upload_id: appeal_submission_upload.id
      )
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')
      get_dr_svc.put_notice_of_disagreement_upload(upload_url:,
                                                   file_upload: sanitized_file,
                                                   metadata_string: appeal_submission.upload_metadata,
                                                   user_uuid: appeal_submission.user_uuid,
                                                   appeal_submission_upload_id: appeal_submission_upload.id)
      upload_url_response
    end

    # Handle supplemental claims appeal type. Make a request to Lighthouse to get the URL where we can upload the
    # file, then get the file from S3 and send it to Lighthouse
    #
    # @param appeal_submission_upload [AppealSubmissionUpload]
    # @param file_number_or_ssn [String] Veteran's SSN or File #
    # @param sanitized_file [CarrierWave::SanitizedFile] The sanitized file from S3
    # @return [Faraday::Env] The response from Lighthouse
    def handle_supplemental_claim(appeal_submission_upload, file_number_or_ssn, sanitized_file)
      Sentry.set_tags(source: '20-0995-supplemental-claim')
      appeal_submission = appeal_submission_upload.appeal_submission
      user_uuid = appeal_submission.user_uuid
      appeal_submission_upload_id = appeal_submission_upload.id
      upload_url_response = get_dr_svc.get_supplemental_claim_upload_url(
        sc_uuid: appeal_submission.submitted_appeal_uuid,
        file_number: file_number_or_ssn,
        user_uuid:,
        appeal_submission_upload_id:
      )
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')
      get_dr_svc.put_supplemental_claim_upload(upload_url:,
                                               file_upload: sanitized_file,
                                               metadata_string: appeal_submission.upload_metadata,
                                               user_uuid:,
                                               appeal_submission_upload_id:)
      upload_url_response
    end

    def self.send_notification_email(upload, submission)
      appeal_type = submission.type_of_appeal
      reference = "#{appeal_type}-evidence-#{upload.lighthouse_upload_id}"

      email_address = submission.current_email_address
      template_id = DecisionReviews::V1::EVIDENCE_TEMPLATE_IDS[appeal_type]
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        filename: upload.masked_attachment_filename,
        date_submitted: upload.created_at.strftime('%B %d, %Y')
      }

      service = ::VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
      service.send_email({ email_address:, template_id:, personalisation:, reference: })
    end
    private_class_method :send_notification_email

    def self.record_email_send_successful(upload, submission, notification_id)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 appeal_submission_upload_id: upload.id,
                 appeal_type:,
                 notification_id: }
      Rails.logger.info('DecisionReviews::SubmitUpload retries exhausted email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted.email_queued")
    end
    private_class_method :record_email_send_successful

    def self.record_email_send_failure(upload, submission, e)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 appeal_submission_upload_id: upload.id,
                 appeal_type:,
                 message: e.message }
      Rails.logger.error('DecisionReviews::SubmitUpload retries exhausted email error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted.email_error", tags: ["appeal_type:#{appeal_type}"])

      service_name = DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]
      tags = ["service:#{service_name}", 'function: evidence submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)
    end
    private_class_method :record_email_send_failure
  end
end
