# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'
require 'decision_review_v1/service'

module DecisionReview
  class Form4142Submit
    include Sidekiq::Job
    include DecisionReviewV1::Appeals::Helpers

    STATSD_KEY_PREFIX = 'worker.decision_review.form4142_submit'

    # 13 retries equates to roughly 1 day using exponential backoff, which should
    # be long enough to resolve transient errors like temporary Central Mail outages.
    sidekiq_options retry: 13

    sidekiq_retries_exhausted do |msg, _ex|
      error_message = msg['error_message']
      appeal_submission_id, _encrypted_payload, submitted_appeal_uuid = msg['args']
      job_id = msg['jid']

      tags = ['service:supplemental-claims-4142', 'function: 21-4142 PDF submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)

      ::Rails.logger.error(
        {
          error_message:,
          message: 'DecisionReview::Form4142Submit retries exhausted',
          form_id: DecisionReviewV1::FORM4142_ID,
          parent_form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
          appeal_submission_id:,
          submitted_appeal_uuid:,
          job_id:
        }
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.permanent_error")
    end

    def decrypt_form(encrypted_payload)
      JSON.parse(DecisionReviewV1::Appeals::Helpers::DR_LOCKBOX.decrypt(encrypted_payload))
    end

    def perform(appeal_submission_id, encrypted_payload, submitted_appeal_uuid)
      rejiggered_payload = decrypt_form(encrypted_payload)
      decision_review_service.process_form4142_submission(appeal_submission_id:, rejiggered_payload:)

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
