# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'
require 'decision_review_v1/service'

module DecisionReview
  class Form4142Submit
    include Sidekiq::Worker

    STATSD_KEY_PREFIX = 'worker.decision_review.form4142_submit'

    sidekiq_options retry: 3

    def decrypt_form(encrypted_payload)
      JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_payload))
    end

    def perform(appeal_submission_id, encrypted_payload, submitted_appeal_uuid)
      decision_review_service.process_form4142_submission(appeal_submission_id:,
                                                          rejiggered_payload: decrypt_form(encrypted_payload))
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      ::Rails.logger.error({
                             error_message: e.message,
                             form_id: DecisionReviewV1::FORM4142_ID,
                             parent_form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
                             message: 'Supplemental Claim Form4142 Queued Job Errored',
                             appeal_submission_id:,
                             lighthouse_submission: {
                               id: submitted_appeal_uuid
                             }
                           })
      raise e
    end

    private

    def decision_review_service
      DecisionReviewV1::Service.new
    end
  end
end
