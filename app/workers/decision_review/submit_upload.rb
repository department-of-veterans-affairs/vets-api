# frozen_string_literal: true

require 'decision_review_v1/service'

module DecisionReview
  class SubmitUpload
    include Sidekiq::Worker
    STATSD_KEY_PREFIX = 'worker.decision_review.submit_upload'

    sidekiq_options retry: 5

    # Make a request to lighthosue to get the URL where we can upload the file,
    # then get the file from S3 and send it to lighthouse
    #
    # @param appeal_submission_upload_id [String] UUID in response from Lighthouse upload
    # @param type [Symbol|String] type of submission one of 'SC','NOD' or :SC, :NOD (case insensitive) default: NOD
    def perform(appeal_submission_upload_id)
      appeal_submission_upload = AppealSubmissionUpload.find(appeal_submission_upload_id)
      appeal_submission = appeal_submission_upload.appeal_submission
      sanitized_file = DecisionReviewEvidenceAttachment.find_by(
        guid: appeal_submission_upload.decision_review_evidence_attachment_guid
      )&.get_file
      file_number_or_ssn = JSON.parse(appeal_submission.upload_metadata)['fileNumber']
      lh_upload_id = case appeal_submission.type_of_appeal
                     when 'NOD'
                       handle_notice_of_disagreement(appeal_submission, file_number_or_ssn, sanitized_file)
                     when 'SC'
                       handle_supplemental_claim(appeal_submission, file_number_or_ssn, sanitized_file)
                     else
                       raise "Unknown appeal type (#{type})"
                     end.body.dig('data', 'id')
      appeal_submission_upload.update!(lighthouse_upload_id: lh_upload_id)
      log_success(internal_id: appeal_submission.id, lighthouse_uuid: appeal_submission.submitted_appeal_uuid,
                  lighthouse_evidence_uuid: lh_upload_id, appeal_type: appeal_submission.type_of_appeal)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      handle_error(e)
    end

    def handle_error(e)
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      raise e
    end

    private

    def log_success(internal_id:, lighthouse_uuid:, lighthouse_evidence_uuid:, appeal_type:)
      Rails.logger.info({
                          message: 'Appeal evidence upload complete',
                          appeal_submission_id: internal_id,
                          appeal_type:,
                          lighthouse_submission: {
                            id: lighthouse_uuid
                          },
                          lighthouse_evidence_upload_id: lighthouse_evidence_uuid
                        })
    end

    def get_dr_svc
      DecisionReviewV1::Service.new
    end

    def handle_notice_of_disagreement(appeal_submission, file_number_or_ssn, sanitized_file)
      Raven.tags_context(source: '10182-board-appeal')
      upload_url_response = get_dr_svc.get_notice_of_disagreement_upload_url(
        nod_uuid: appeal_submission.submitted_appeal_uuid,
        file_number: file_number_or_ssn
      )
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')
      get_dr_svc.put_notice_of_disagreement_upload(upload_url:,
                                                   file_upload: sanitized_file,
                                                   metadata_string: appeal_submission.upload_metadata)
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
