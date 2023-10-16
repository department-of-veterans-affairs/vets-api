# frozen_string_literal: true

require 'decision_review_v1/service'
require 'decision_review_v1/utilities/logging_utils'

module DecisionReview
  class SubmitUpload
    include Sidekiq::Job
    include DecisionReviewV1::Appeals::LoggingUtils

    STATSD_KEY_PREFIX = 'worker.decision_review.submit_upload'

    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |_msg, _ex|
      StatsD.increment("#{STATSD_KEY_PREFIX}.permanent_error")
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
                       handle_supplemental_claim(appeal_submission, file_number_or_ssn, sanitized_file)
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
    # @param form_attachment [AppealSubmissionUpload]
    # @return [CarrierWave::SanitizedFile] The sanitized file from S3
    def get_sanitized_file!(form_attachment:) # rubocop:disable Metrics/MethodLength
      appeal_submission_upload = form_attachment.appeal_submission_upload
      appeal_submission = appeal_submission_upload.appeal_submission
      # For now, I'm limiting our new `log_formatted` style of logging to the NOD form. In the near future, we will
      # expand this style of logging to every Decision Review form.
      is_nod_submission = appeal_submission.type_of_appeal == 'NOD'
      common_log_params = {
        key: :evidence_upload_retrieval,
        form_id: '10182',
        user_uuid: appeal_submission.user_uuid,
        upstream_system: 'AWS S3',
        params: {
          appeal_submission_upload_id: appeal_submission_upload.id,
          form_attachment_id: form_attachment.id
        }
      }

      begin
        sanitized_file = form_attachment.get_file
        log_formatted(**common_log_params.merge(is_success: true)) if is_nod_submission
        sanitized_file
      rescue => e
        log_formatted(**common_log_params.merge(is_success: false, response_error: e)) if is_nod_submission
        raise e
      end
    end

    def get_dr_svc
      DecisionReviewV1::Service.new
    end

    # Handle notice of disagreement appeal type. Make a request to Lighthouse to get the URL where we can upload the
    # file, then get the file from S3 and send it to Lighthouse
    #
    # @param appeal_submission_upload [AppealSubmissionUpload]
    # @param file_number_or_ssn [String] Veteran's SSN or File #
    # @param sanitized_file [CarrierWave::SanitizedFile] The sanitized file from S3
    # @return [Faraday::Env] The response from Lighthouse
    def handle_notice_of_disagreement(appeal_submission_upload, file_number_or_ssn, sanitized_file)
      Raven.tags_context(source: '10182-board-appeal')
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

    def handle_supplemental_claim(appeal_submission, file_number_or_ssn, sanitized_file)
      Raven.tags_context(source: '20-0995-supplemental-claim')
      upload_url_response = get_dr_svc.get_supplemental_claim_upload_url(
        sc_uuid: appeal_submission.submitted_appeal_uuid,
        file_number: file_number_or_ssn
      )
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')
      get_dr_svc.put_supplemental_claim_upload(upload_url:,
                                               file_upload: sanitized_file,
                                               metadata_string: appeal_submission.upload_metadata)
      upload_url_response
    end
  end
end
