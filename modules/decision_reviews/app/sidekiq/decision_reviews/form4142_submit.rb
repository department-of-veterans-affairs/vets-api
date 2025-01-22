# frozen_string_literal: true

require 'decision_reviews/v1/constants'
require 'decision_reviews/v1/service'
require 'decision_reviews/v1/helpers'

module DecisionReviews
  class Form4142Submit
    include Sidekiq::Job
    include DecisionReviews::V1::Helpers

    STATSD_KEY_PREFIX = 'worker.decision_review.form4142_submit'

    # Increasing to 17 retries, approximately 3 days, for ~39 hour COLA maintenance
    sidekiq_options retry: 17

    sidekiq_retries_exhausted do |msg, _ex|
      error_message = msg['error_message']
      appeal_submission_id, _encrypted_payload, submitted_appeal_uuid = msg['args']
      job_id = msg['jid']

      ::Rails.logger.error(
        {
          error_message:,
          message: 'DecisionReviews::Form4142Submit retries exhausted',
          form_id: DecisionReviews::V1::FORM4142_ID,
          parent_form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
          appeal_submission_id:,
          submitted_appeal_uuid:,
          job_id:
        }
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.permanent_error")

      begin
        submission = AppealSubmission.find(appeal_submission_id)
        response = send_notification_email(submission)

        record_email_send_successful(submission, response.id)
      rescue => e
        record_email_send_failure(submission, e)
      end
    end

    def decrypt_form(encrypted_payload)
      JSON.parse(DecisionReviews::V1::Helpers::DR_LOCKBOX.decrypt(encrypted_payload))
    end

    def perform(appeal_submission_id, encrypted_payload, submitted_appeal_uuid)
      rejiggered_payload = decrypt_form(encrypted_payload)
      decision_review_service.process_form4142_submission(appeal_submission_id:, rejiggered_payload:)

      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      ::Rails.logger.error({
                             error_message: e.message,
                             form_id: DecisionReviews::V1::FORM4142_ID,
                             parent_form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
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
      DecisionReviews::V1::Service.new
    end

    def self.send_notification_email(submission)
      appeal_type = submission.type_of_appeal
      created_at = submission.created_at
      reference = "#{appeal_type}-secondary_form-#{submission.submitted_appeal_uuid}"

      email_address = submission.current_email_address
      template_id = DecisionReviews::V1::SECONDARY_FORM_TEMPLATE_ID
      personalisation = {
        first_name: submission.get_mpi_profile.given_names[0],
        date_submitted: created_at.strftime('%B %d, %Y')
      }

      service = ::VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
      service.send_email({ email_address:, template_id:, personalisation:, reference: })
    end
    private_class_method :send_notification_email

    def self.record_email_send_successful(submission, notification_id)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 appeal_type:,
                 notification_id: }
      Rails.logger.info('DecisionReviews::Form4142Submit retries exhausted email queued', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted.email_queued")
    end
    private_class_method :record_email_send_successful

    def self.record_email_send_failure(submission, e)
      appeal_type = submission.type_of_appeal
      params = { submitted_appeal_uuid: submission.submitted_appeal_uuid,
                 appeal_type:,
                 message: e.message }
      Rails.logger.error('DecisionReviews::Form4142Submit retries exhausted email error', params)
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted.email_error", tags: ["appeal_type:#{appeal_type}"])

      tags = ['service:supplemental-claims', 'function: secondary form submission to Lighthouse']
      StatsD.increment('silent_failure', tags:)
    end
    private_class_method :record_email_send_failure
  end
end
