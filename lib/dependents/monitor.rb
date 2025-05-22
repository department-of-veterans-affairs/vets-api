# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module Dependents
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'dependent-change'

    # statsd key for initial sidekiq
    BGS_SUBMISSION_STATS_KEY = 'worker.submit_686c_674_bgs'

    # stats key for pdf submission
    PDF_SUBMISSION_STATS_KEY = 'worker.submit_dependents_pdf'

    # statsd key for backup sidekiq
    SUBMISSION_STATS_KEY = 'worker.submit_686c_674_backup_submission'

    # statsd key for email notifications
    EMAIL_STATS_KEY = 'dependents.email_notification'

    def initialize(claim_id)
      @claim_id = claim_id
      @claim = claim(claim_id)
      @use_v2 = use_v2
      super('dependents-application')
    end

    def use_v2
      return nil unless @claim

      @claim&.use_v2 || @claim&.form_id&.include?('-V2')
    end

    def claim(claim_id)
      SavedClaim::DependencyClaim.find(claim_id)
    rescue => e
      Rails.logger.warn('Unable to find claim for Dependents::Monitor', { claim_id:, e: })
    end

    def default_payload
      { service:, use_v2: @use_v2, claim_id: @claim_id }
    end

    def tags
      ["service:#{service}", "v2:#{@use_v2}"]
    end

    def track_submission_exhaustion(msg, email = nil)
      additional_context = {
        message: msg
      }
      if email
        # if an email address is present it means an email has been sent by vanotify
        # this means the silent failure is avoided.
        log_silent_failure_no_confirmation(additional_context, call_location: caller_locations.first)
      else
        # if no email is present, log silent failure
        log_silent_failure(additional_context, call_location: caller_locations.first)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted", tags:)
      Rails.logger.error(
        'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
        "last error: #{msg['error_message']}"
      )
    end

    def track_unknown_claim_type(e)
      metric = "#{EMAIL_STATS_KEY}.unknown_type"
      payload = default_payload.merge({ statsd: metric, e: })

      StatsD.increment(metric, tags:)
      Rails.logger.error("Unknown Dependents form type for claim #{@claim_id}", payload)
    end

    def track_send_email_success(message, metric, user_account_id = nil)
      payload = default_payload.merge({ statsd: metric, user_account_id: })

      StatsD.increment(metric, tags:)
      Rails.logger.info(message, payload)
    end

    def track_send_email_error(message, metric, e, user_account_uuid = nil)
      payload = default_payload.merge({ statsd: metric, e:, user_account_uuid: })

      StatsD.increment(metric, tags:)
      Rails.logger.error(message, payload)
    end

    def track_send_submitted_email_success(user_account_uuid = nil)
      track_send_email_success("'Submitted' email success for claim #{@claim_id}",
                               "#{EMAIL_STATS_KEY}.submitted.success",
                               user_account_uuid)
    end

    def track_send_submitted_email_failure(e, user_account_uuid = nil)
      track_send_email_error("'Submitted' email failure for claim #{@claim_id}",
                             "#{EMAIL_STATS_KEY}.submitted.failure",
                             e, user_account_uuid)
    end

    def track_send_received_email_success(user_account_uuid = nil)
      track_send_email_success("'Received' email success for claim #{@claim_id}", "#{EMAIL_STATS_KEY}.received.success",
                               user_account_uuid)
    end

    def track_send_received_email_failure(e, user_account_uuid = nil)
      track_send_email_failure("'Received' email failure for claim #{@claim_id}", "#{EMAIL_STATS_KEY}.received.failure",
                               e, user_account_uuid)
    end

    def track_to_pdf_failure(e)
      metric = "#{CLAIM_STATS_KEY}.to_pdf.failure"
      metric = "#{metric}.v2" if @use_v2
      payload = default_payload.merge({ statsd: metric, e: })

      StatsD.increment(metric, tags:)
      Rails.logger.error('SavedClaim::DependencyClaim#to_pdf error', payload)
    end

    def track_pdf_overflow_tracking_failure(e)
      metric = "#{CLAIM_STATS_KEY}.track_pdf_overflow.failure"
      metric = "#{metric}.v2" if @use_v2
      payload = default_payload.merge({ statsd: metric, e: })

      StatsD.increment(metric, tags:)
      Rails.logger.error('Error tracking PDF overflow', payload)
    end

    def track_pdf_overflow(form_id)
      tags = ["form_id:#{form_id}"]
      metric = 'saved_claim.pdf.overflow'
      StatsD.increment(metric, tags:)
    end

    def dependent_service_submit_pdf_job_begin
      message = 'BGS::DependentService#submit_pdf_job called to begin VBMS::SubmitDependentsPdfJob'
      Rails.logger.info(message, default_payload)
    end

    def dependent_service_submit_pdf_job_failure(icn, error)
      message = 'DependentService#submit_pdf_job method failed, submitting to Lighthouse Benefits Intake'
      payload = default_payload.merge({ icn:, error: })
      Rails.logger.error(message, payload)
    end

    def dependent_service_begin(user_uuid, icn)
      message = 'BGS::DependentService running!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def dependent_service_failure(user_uuid, icn, error)
      message = 'BGS::DependentService#submit_686c_form method failed!'
      payload = default_payload.merge({ user_uuid:, icn:, error: })
      Rails.logger.error(message, payload)
    end

    def dependent_service_success(user_uuid, icn)
      message = 'BGS::DependentService succeeded!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def form_686_job_begin(user_uuid, icn)
      message = 'BGS::SubmitForm686cJob running!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def form_686_job_failure(user_uuid, icn, error, nested_error)
      message = 'BGS::SubmitForm686cJob received error, retrying...'
      payload = default_payload.merge({ user_uuid:, icn:, error:, nested_error: })
      Rails.logger.warn(message, payload)
    end

    def form_686_job_skip_retries(user_uuid, icn, error, nested_error)
      message = 'BGS::SubmitForm686cJob received error, skipping retries...'
      payload = default_payload.merge({ user_uuid:, icn:, error:, nested_error: })
      Rails.logger.error(message, payload)
    end

    def form_686_job_success(user_uuid, icn)
      message = 'BGS::SubmitForm686cJob succeeded!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def form_686_job_exhaustion(user_uuid, icn, msg)
      message = "BGS::SubmitForm686cJob failed, retries exhausted! Last error: #{msg['error_message']}"
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.error(message, payload)
    end

    def form_686_job_backup_submission_failure(payload)
      message = 'BGS::SubmitForm686cJob backup submission failed...'
      Rails.logger.error(message, default_payload.merge(payload))
    end

    def form_674_job_begin(user_uuid, icn)
      message = 'BGS::SubmitForm674Job running!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def form_674_job_failure(user_uuid, icn, error, nested_error)
      message = 'BGS::SubmitForm674Job received error, retrying...'
      payload = default_payload.merge({ user_uuid:, icn:, error:, nested_error: })
      Rails.logger.warn(message, payload)
    end

    def form_674_job_success(user_uuid, icn)
      message = 'BGS::SubmitForm674Job succeeded!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def form_674_job_skip_retries(user_uuid, icn, error, nested_error)
      message = 'BGS::SubmitForm674Job received error, skipping retries...'
      payload = default_payload.merge({ user_uuid:, icn:, error:, nested_error: })
      Rails.logger.error(message, payload)
    end

    def form_674_job_exhaustion(user_uuid, icn, msg)
      message = "BGS::SubmitForm674Job failed, retries exhausted! Last error: #{msg['error_message']}"
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.error(message, payload)
    end

    def form_674_job_backup_submission_failure(payload)
      message = 'BGS::SubmitForm674Job backup submission failed...'
      payload = default_payload.merge(payload)
      Rails.logger.error(message, payload)
    end

    def dependent_pdf_job_begin
      message = 'VBMS::SubmitDependentsPdfJob running!'
      Rails.logger.info(message, default_payload)
    end

    def dependent_pdf_job_failure(error)
      message = 'VBMS::SubmitDependentsPdfJob failed, retrying...'
      payload = default_payload.merge({ error: })
      Rails.logger.warn(message, payload)
    end

    def dependent_pdf_job_success
      message = 'VBMS::SubmitDependentsPdfJob succeeded!'
      Rails.logger.info(message, default_payload)
    end

    def submission_backup_begin(user_uuid, icn)
      message = 'Lighthouse::BenefitsIntake::SubmitCentralForm686cJob running!'
      payload = default_payload.merge({ user_uuid:, icn: })
      Rails.logger.info(message, payload)
    end

    def submission_backup_failure(user_uuid, icn, e)
      message = 'Lighthouse::BenefitsIntake::SubmitCentralForm686cJob failed!'
      payload = default_payload.merge({ user_uuid:, icn:, e: })
      Rails.logger.error(message, payload)
    end

    def submission_backup_success(user_uuid)
      message = 'SubmitCentralForm686cJob Lighthouse Submission Successful'
      payload = default_payload.merge({ user_uuid: })
      Rails.logger.info(message, payload)
    end
  end
end
