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

    # StatsD key for benefits intake failures
    BENEFITS_INTAKE_STATS_KEY = 'vff.benefits_intake'

    def initialize
      super('veteran-facing-forms')
    end



    # Track benefits intake failures following established ZSF pattern
    # Similar to PCPG::Monitor#track_submission_exhaustion and VRE::Monitor#track_submission_exhaustion
    #
    # @param benefits_intake_uuid [String] Benefits Intake UUID
    # @param form_id [String] VFF form identifier (e.g., '21-0966')
    # @param email_sent [Boolean] whether an email notification is expected for this failure
    def track_benefits_intake_failure(benefits_intake_uuid, form_id, email_sent = false) # rubocop:disable Style/OptionalBooleanParameter
      additional_context = {
        benefits_intake_uuid:,
        form_id:
      }

      if email_sent
        # Email notification expected - silent failure likely to be avoided, but delivery not confirmed here
        log_silent_failure_no_confirmation(additional_context, nil, call_location: caller_locations.first)
      else
        # No email notification expected - true silent failure
        log_silent_failure(additional_context, nil, call_location: caller_locations.first)
      end

      # Simple StatsD metric following established pattern
      StatsD.increment("#{BENEFITS_INTAKE_STATS_KEY}.failure", tags: ["form_id:#{form_id}", "service:#{service}"])

      Rails.logger.error(
        "VFF Benefits Intake failure for form #{form_id}",
        {
          service:,
          benefits_intake_uuid:,
          form_id:,
          email_sent: email_sent,
          email_notification_expected: email_sent
        }
      )
    end

    # Track failed email notification for VFF forms
    # Used by SendNotificationEmailJob when email sending fails
    #
    # @param form_type [String] VFF form identifier
    # @param confirmation_number [String] form confirmation number
    # @param error [Exception] the error that occurred
    # @param additional_context [Hash] extra context for logging
    def track_email_notification_failure(form_type, confirmation_number, error, additional_context = {})
      context = {
        form_id: form_type,
        confirmation_number:,
        error_class: error.class.name,
        error_message: error.message,
        **additional_context
      }

      StatsD.increment(
        "#{BENEFITS_INTAKE_STATS_KEY}.email_failure",
        tags: ["form_id:#{form_type}", "service:#{service}"]
      )
      Rails.logger.error('VFF email notification failed', { service:, **context })
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
