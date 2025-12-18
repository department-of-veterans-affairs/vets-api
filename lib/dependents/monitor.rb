# frozen_string_literal: true

require 'zero_silent_failures/monitor'
require 'logging/base_monitor'

module Dependents
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'dependent-change'

    # statsd key for initial sidekiq
    BGS_SUBMISSION_STATS_KEY = 'worker.submit_686c_674_bgs'

    # stats key for pdf submission
    PDF_SUBMISSION_STATS_KEY = 'worker.submit_dependents_pdf'

    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.submit_686c_674_backup_submission'

    # statsd key for email notifications
    EMAIL_STATS_KEY = 'dependents.email_notification'

    # statsd key for pension-related submissions
    PENSION_SUBMISSION_STATS_KEY = 'dependents.submit_dependents_pension'

    # allowed logging params
    ALLOWLIST = %w[
      tags
      use_v2
    ].freeze

    attr_writer :form_id

    # create a dependents monitor
    #
    # @param claim_id [Integer] the database SavedClaim id
    # @param form_id [String] the form being monitored; 686c-674 or 21-674, etc
    def initialize(claim_id, form_id = nil)
      @claim_id = claim_id
      @claim = claim(claim_id)
      @use_v2 = use_v2
      @form_id = form_id || @claim&.form_id

      super('dependents-application', allowlist: ALLOWLIST)

      @tags += ["service:#{service}", "v2:#{@use_v2}"]
    end

    def name
      self.class.to_s
    end

    def form_id
      @form_id ||= @claim&.form_id
    end

    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    def use_v2
      return nil unless @claim

      @claim&.use_v2 || @claim&.form_id&.include?('-V2')
    end

    def claim(claim_id)
      SavedClaim::DependencyClaim.find(claim_id) unless claim_id.nil?
    rescue => e
      Rails.logger.warn('Unable to find claim for Dependents::Monitor', { claim_id:, e: })
      nil
    end

    def default_payload
      { service:, use_v2: @use_v2, claim: @claim, user_account_uuid: nil, tags: }
    end

    def track_submission_exhaustion(msg, email = nil)
      additional_context = default_payload.merge({ error: msg })
      if email
        # if an email address is present it means an email has been sent by vanotify
        # this means the silent failure is avoided.
        log_silent_failure_avoided(additional_context, call_location: caller_locations.first)
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
      track_send_email_failure(
        @claim,
        nil, # lighthouse_service (I don't know if we have this) TODO: Research by application team.
        user_account_uuid,
        'submitted',
        e
      )
    end

    def track_pdf_upload_error
      metric = "#{CLAIM_STATS_KEY}.upload_pdf.failure"
      metric = "#{metric}.v2" if @use_v2
      payload = default_payload.merge({ statsd: metric })

      track_event('error', 'DependencyClaim error in upload_to_vbms method', metric, payload)
    end

    def track_to_pdf_failure(e, form_id)
      metric = "#{CLAIM_STATS_KEY}.to_pdf.failure"
      metric = "#{metric}.v2" if @use_v2
      payload = default_payload.merge({ statsd: metric, e:, form_id: })

      StatsD.increment(metric, tags:)
      Rails.logger.error('SavedClaim::DependencyClaim#to_pdf error', payload)
    end

    def track_pdf_overflow_tracking_failure(e)
      metric = "#{CLAIM_STATS_KEY}.track_pdf_overflow.failure"
      metric = "#{metric}.v2" if @use_v2
      payload = default_payload.merge({ statsd: metric, e: })

      StatsD.increment(metric, tags:)
      Rails.logger.warn('Error tracking PDF overflow', payload)
    end

    def track_pdf_overflow(form_id)
      tags = ["form_id:#{form_id}"]
      metric = 'saved_claim.pdf.overflow'
      StatsD.increment(metric, tags:)
    end

    def track_pension_related_submission(form_id:, form_type:)
      tags = ["form_id:#{form_id}"]
      metric = "#{PENSION_SUBMISSION_STATS_KEY}.#{form_type}.submitted"
      StatsD.increment(metric, tags:)
    end

    def track_event(level, message, stats_key, payload = {})
      payload = default_payload.merge(payload)
      submit_event(level, message, stats_key, **payload)
    rescue => e
      Rails.logger.error('Dependents::Monitor#track_event error',
                         level:, message:, stats_key:, payload:, error: e.message)
    end

    def claim_stats_key
      CLAIM_STATS_KEY
    end
  end
end
