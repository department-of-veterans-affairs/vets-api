# frozen_string_literal: true

require 'logging/controller/monitor'
require 'logging/benefits_intake/monitor'

module Logging
  class BaseMonitor < ::ZeroSilentFailures::Monitor
    include Logging::Controller::Monitor
    include Logging::BenefitsIntake::Monitor

    private

    def message_prefix
      "#{name} #{form_id}"
    end

    # Abstract methods
    def service_name
      raise NotImplementedError, 'Subclasses must implement service_name'
    end

    def claim_stats_key
      raise NotImplementedError, 'Subclasses must implement claim_stats_key'
    end

    def submission_stats_key
      raise NotImplementedError, 'Subclasses must implement submission_stats_key'
    end

    def name
      raise NotImplementedError, 'Subclasses must implement name'
    end

    def form_id
      raise NotImplementedError, 'Subclasses must implement form_id'
    end

    # Default implementation for sending emails
    # Subclasses can override this method to provide custom email functionality
    #
    # @param claim_id [Integer] The ID of the claim
    # @param email_type [Symbol] The type of the email (e.g., :error, :submitted)
    def send_email(claim_id, email_type)
      # Default implementation does nothing
    end

    ##
    # Submits an event for tracking with standardized payload structure
    #
    # @param level [String] The severity level of the event (e.g., :error, :info, :warn)
    # @param message [String] The message describing the event
    # @param stats_key [String] The key used for stats tracking
    # @param options [Hash] Additional options for the event
    #   @option options [SavedClaim, Integer, nil] :claim The claim object or claim ID
    #   @option options [String, nil] :user_account_uuid The UUID of the user account
    #   @option options [Hash] :**additional_context Additional context for the event
    #
    def submit_event(level, message, stats_key, options = {})
      claim = options[:claim]
      user_account_uuid = options[:user_account_uuid]
      additional_context = options.except(:claim, :user_account_uuid)

      claim_id = claim.respond_to?(:id) ? claim.id : claim
      confirmation_number = claim.respond_to?(:confirmation_number) ? claim.confirmation_number : nil
      form_id = claim.respond_to?(:form_id) ? claim.form_id : nil
      tags = @tags || options[:tags] || []

      payload = {
        confirmation_number:,
        user_account_uuid:,
        claim_id:,
        form_id:,
        tags:,
        **additional_context
      }

      track_request(level, message, stats_key, call_location: caller_locations.first, **payload)
    end
  end
end
