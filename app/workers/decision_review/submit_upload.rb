# frozen_string_literal: true

require 'decision_review/service'

module DecisionReview
  class SubmitUpload
    include Sidekiq::Worker
    STATSD_KEY_PREFIX = 'worker.decision_review.submit_upload'

    sidekiq_options retry: 5

    #
    #
    # @param user_uuid [String] The user uuid
    # @param upload_attrs [Hash] {name: "file.pdf", confirmationCode: "uuid" }
    # @param appeal_submission_id [String] UUID in response from Lighthouse
    #
    # Make a request to lighthosue to get the URL where we can upload the file,
    # then get the file from S3 and send it to lighthouse

    def perform(appeal_submission_id, upload_attrs)
      Raven.tags_context(source: '10182-board-appeal')
      appeal_submission = AppealSubmission.find(appeal_submission_id)
      upload_url_response = DecisionReview::Service.new
                                                   .get_notice_of_disagreement_upload_url(nod_id:
                                                    appeal_submission.submitted_appeal_uuid)
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')

      decision_review_evidence_attachment_guid = upload_attrs['confirmationCode']
      appeal_submission_upload = AppealSubmissionUpload.create(
        decision_review_evidence_attachment_guid: decision_review_evidence_attachment_guid,
        appeal_submission_id: appeal_submission_id
      )

      carrierwave_sanitized_file = DecisionReviewEvidenceAttachment.find_by(
        guid: decision_review_evidence_attachment_guid
      )
                                  &.get_file
      DecisionReview::Service.new.put_notice_of_disagreement_upload(upload_url: upload_url,
                                                                    file_path: carrierwave_sanitized_file.path,
                                                                    metadata: {})
      appeal_submission_upload.lighthouse_upload_id = upload_url_response.body.dig('data', 'id')
      appeal_submission_upload.save
    end
  end
end
