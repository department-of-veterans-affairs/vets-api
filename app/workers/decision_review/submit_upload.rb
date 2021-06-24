# frozen_string_literal: true

require 'decision_review/service'

module DecisionReview
  class SubmitUpload
    include Sidekiq::Worker
    STATSD_KEY_PREFIX = 'worker.decision_review.submit_upload'

    sidekiq_options retry: 5

    # Make a request to lighthosue to get the URL where we can upload the file,
    # then get the file from S3 and send it to lighthouse
    #
    # @param appeal_submission_upload_id [String] The user uuid
    # @param appeal_submission_id [String] UUID in response from Lighthouse

    def perform(appeal_submission_upload_id)
      Raven.tags_context(source: '10182-board-appeal')
      appeal_submission_upload = AppealSubmissionUpload.find(appeal_submission_upload_id)
      appeal_submission = appeal_submission_upload.appeal_submission
      upload_url_response = DecisionReview::Service.new
                                                   .get_notice_of_disagreement_upload_url(
                                                     nod_uuid: appeal_submission.submitted_appeal_uuid,
                                                     ssn: JSON.parse(appeal_submission.upload_metadata)['fileNumber']
                                                   )
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')

      carrierwave_sanitized_file = DecisionReviewEvidenceAttachment.find_by(
        guid: appeal_submission_upload.decision_review_evidence_attachment_guid
      )&.get_file

      DecisionReview::Service.new.put_notice_of_disagreement_upload(upload_url: upload_url,
                                                                    file_upload: carrierwave_sanitized_file,
                                                                    metadata_string: appeal_submission.upload_metadata)

      appeal_submission_upload.lighthouse_upload_id = upload_url_response.body.dig('data', 'id')
      appeal_submission_upload.save
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      handle_error(e)
    end

    def handle_error(e)
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      raise e
    end
  end
end
