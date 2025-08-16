# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module VFF
  ##
  # Monitor functions for VFF (Veterans Facing Forms) Rails logging and StatsD
  # Provides tracking for silent failures in VFF form submissions
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # VFF form identifiers that use this monitoring
    VFF_FORM_IDS = %w[
      21-0966
      21-4142
      21-10210
      21-0972
      21P-0847
      20-10206
      20-10207
      21-0845
    ].freeze

    # StatsD key prefixes
    BENEFITS_INTAKE_STATS_KEY = 'vff.benefits_intake'
    EMAIL_NOTIFICATION_STATS_KEY = 'vff.email_notification'
    FORM_SUBMISSION_STATS_KEY = 'vff.form_submission'

    def initialize
      super('veteran-facing-forms')
    end

    # Main tracking method for benefits intake failures from BenefitsIntakeStatusJob
    #
    # @param context [Hash] failure context with form_id, saved_claim_id, benefits_intake_uuid
    # @param form_submission [FormSubmission] optional form submission object for additional context
    # @param email_attempted [Boolean] whether email notification was attempted
    # @param email_success [Boolean] whether email notification succeeded (if attempted)
    def track_benefits_intake_failure(context, form_submission: nil, email_attempted: false, email_success: false)
      additional_context = build_failure_context(context, form_submission)
      user_account_uuid = extract_user_account_uuid(form_submission)
      call_location = caller_locations.first

      # Log appropriate ZSF metric based on email status
      if email_attempted && email_success
        log_silent_failure_avoided(additional_context, user_account_uuid, call_location: call_location)
      elsif email_attempted && !email_success
        log_silent_failure_no_confirmation(additional_context, user_account_uuid, call_location: call_location)
      else
        log_silent_failure(additional_context, user_account_uuid, call_location: call_location)
      end

      # Log VFF-specific metrics
      form_id = context[:form_id]
      StatsD.increment("#{BENEFITS_INTAKE_STATS_KEY}.failure", tags: ["form_id:#{form_id}", "service:#{service}"])
      StatsD.increment("#{BENEFITS_INTAKE_STATS_KEY}.failure.all_forms", tags: ["service:#{service}"])

      # Log detailed information
      Rails.logger.error(
        'VFF Benefits Intake failure tracked',
        {
          service: service,
          form_id: form_id,
          email_attempted: email_attempted,
          email_success: email_success,
          **additional_context
        }
      )
    end

    # Track form submission failures with detailed context
    #
    # @param form_submission [FormSubmission] the form submission that failed
    # @param form_submission_attempt [FormSubmissionAttempt] the specific attempt that failed
    # @param failure_type [String] type of failure (expired, error, etc.)
    # @param error_details [Hash] specific error information
    # @param email_attempted [Boolean] whether email notification was attempted
    # @param email_success [Boolean] whether email notification succeeded
    def track_form_submission_failure(form_submission, form_submission_attempt, failure_type, error_details = {}, email_attempted: false, email_success: false)
      additional_context = {
        form_id: form_submission.form_type,
        form_submission_id: form_submission.id,
        form_submission_attempt_id: form_submission_attempt.id,
        benefits_intake_uuid: form_submission_attempt.benefits_intake_uuid,
        failure_type: failure_type,
        lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at,
        error_message: form_submission_attempt.error_message,
        **error_details
      }

      user_account_uuid = extract_user_account_uuid(form_submission)
      call_location = caller_locations.first

      # Log appropriate ZSF metric
      if email_attempted && email_success
        log_silent_failure_avoided(additional_context, user_account_uuid, call_location: call_location)
      elsif email_attempted && !email_success
        log_silent_failure_no_confirmation(additional_context, user_account_uuid, call_location: call_location)
      else
        log_silent_failure(additional_context, user_account_uuid, call_location: call_location)
      end

      # Log VFF-specific submission metrics
      form_id = form_submission.form_type
      StatsD.increment("#{FORM_SUBMISSION_STATS_KEY}.#{failure_type}", tags: ["form_id:#{form_id}", "service:#{service}"])

      Rails.logger.error(
        "VFF Form submission #{failure_type} failure",
        {
          service: service,
          email_attempted: email_attempted,
          email_success: email_success,
          **additional_context
        }
      )
    end

    # Track email notification attempts
    #
    # @param form_type [String] VFF form identifier
    # @param confirmation_number [String] form confirmation number
    # @param additional_context [Hash] extra context for logging
    def track_email_notification_attempt(form_type, confirmation_number, additional_context = {})
      context = {
        form_id: form_type,
        confirmation_number: confirmation_number,
        **additional_context
      }

      StatsD.increment("#{EMAIL_NOTIFICATION_STATS_KEY}.attempt", tags: ["form_id:#{form_type}", "service:#{service}"])
      Rails.logger.info('VFF email notification attempted', { service: service, **context })
    end

    # Track successful email notification
    #
    # @param form_type [String] VFF form identifier
    # @param confirmation_number [String] form confirmation number
    # @param additional_context [Hash] extra context for logging
    def track_email_notification_success(form_type, confirmation_number, additional_context = {})
      context = {
        form_id: form_type,
        confirmation_number: confirmation_number,
        **additional_context
      }

      StatsD.increment("#{EMAIL_NOTIFICATION_STATS_KEY}.success", tags: ["form_id:#{form_type}", "service:#{service}"])
      Rails.logger.info('VFF email notification succeeded', { service: service, **context })
    end

    # Track failed email notification
    #
    # @param form_type [String] VFF form identifier
    # @param confirmation_number [String] form confirmation number
    # @param error [Exception] the error that occurred
    # @param additional_context [Hash] extra context for logging
    def track_email_notification_failure(form_type, confirmation_number, error, additional_context = {})
      context = {
        form_id: form_type,
        confirmation_number: confirmation_number,
        error_class: error.class.name,
        error_message: error.message,
        **additional_context
      }

      StatsD.increment("#{EMAIL_NOTIFICATION_STATS_KEY}.failure", tags: ["form_id:#{form_type}", "service:#{service}"])
      Rails.logger.error('VFF email notification failed', { service: service, **context })
    end

    private

    # Build comprehensive failure context for logging and debugging
    #
    # @param context [Hash] basic context with form_id, saved_claim_id, benefits_intake_uuid
    # @param form_submission [FormSubmission] optional form submission for additional context
    # @return [Hash] enriched context for logging
    def build_failure_context(context, form_submission = nil)
      base_context = {
        form_id: context[:form_id],
        claim_id: context[:saved_claim_id],
        benefits_intake_uuid: context[:benefits_intake_uuid]
      }

      return base_context unless form_submission

      base_context.merge(
        form_submission_id: form_submission.id,
        form_submission_created_at: form_submission.created_at,
        latest_attempt_id: form_submission.latest_attempt&.id,
        latest_attempt_state: form_submission.latest_attempt&.aasm_state,
        user_account_id: form_submission.user_account_id
      )
    end

    # Extract user account UUID from form submission
    #
    # @param form_submission [FormSubmission] form submission object
    # @return [String, nil] user account UUID if available
    def extract_user_account_uuid(form_submission)
      form_submission&.user_account_id
    end

    # Class method to check if a form ID is a VFF form
    # This allows external classes to check without instantiating a monitor
    #
    # @param form_id [String] form identifier
    # @return [Boolean] true if form is a VFF form
    def self.vff_form?(form_id)
      VFF_FORM_IDS.include?(form_id)
    end
  end
end