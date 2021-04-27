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
    def perform(user_uuid, appeal_submission_id, upload_attrs)
      Raven.tags_context(source: '10182-board-appeal')
      upload_url_response = DecisionReview::Service.new
                                                   .get_notice_of_disagreement_upload_url(nod_id: appeal_submission_id)
      upload_url = upload_url_response.body.dig('data', 'attributes', 'location')
      upload_id = upload_url_response.body.dig('data', 'id')
      Rails.logger.info "DecisionReview::SubmitUpload upload #{upload_id} uploaded for user #{user_uuid}"
      carrierwave_sanitized_file = DecisionReviewEvidenceAttachment.find_by(guid: upload_attrs['confirmationCode'])
                                  &.get_file
      DecisionReview::Service.new.put_notice_of_disagreement_upload(upload_url: upload_url,
                                                                    file_path: carrierwave_sanitized_file.path,
                                                                    metadata: {})
    end
  end
end
