# frozen_string_literal: true

require 'logging/include/controller'
require 'logging/include/benefits_intake'
require 'logging/include/zero_silent_failures'

module Logging
  # general monitor class to inherit
  class BaseMonitor < ::Logging::Monitor
    include Logging::Include::Controller
    include Logging::Include::BenefitsIntake
    include Logging::Include::ZeroSilentFailures

    # allowed logging params
    # compiled from _this_ and the included modules
    # used to filter the context passed to logging
    ALLOWLIST = %w[
      benefits_intake_uuid
      claim_id
      confirmation_number
      error
      errors
      form_id
      in_progress_form_id
      user_account_uuid
    ].freeze

    attr_reader :tags

    # create a monitor and assign `tags` instance variable
    #
    # @param service [String] the service name for this monitor; will be included with each log message
    # @param allowlist [Array<String>] the list of allowed parameters
    # @param safe_keys [Array<String>] the list of safe keys whose values can be logged without redaction
    def initialize(service, allowlist: [], safe_keys: [])
      @tags = ["form_id:#{form_id}"]
      @allowlist = ALLOWLIST + allowlist
      @safe_keys = safe_keys

      super(service, allowlist: @allowlist, safe_keys: @safe_keys)
    end

    private

    # message prefix to prepend
    # @return [String]
    def message_prefix
      "#{name} #{form_id}"
    end

    # Abstract methods

    # Stats key for Sidekiq DD logging
    # @return [String]
    def claim_stats_key
      raise NotImplementedError, 'Subclasses must implement claim_stats_key'
    end

    # Stats key for Sidekiq DD logging
    # @return [String]
    def submission_stats_key
      raise NotImplementedError, 'Subclasses must implement submission_stats_key'
    end

    # Name to be used in monitor messages
    # @see #message_prefix
    # @return [String]
    def name
      raise NotImplementedError, 'Subclasses must implement name'
    end

    # Form Id to be used in monitor messages
    # @see #message_prefix
    # @return [String]
    def form_id
      raise NotImplementedError, 'Subclasses must implement form_id'
    end

    # Submits an event for tracking with standardized payload structure
    # @see Logging::Monitor#track_request
    #
    # @param level [String|Symbol] The severity level of the event (e.g., :error, :info, :warn)
    # @param message [String] The message describing the event
    # @param stats_key [String] The key used for stats tracking
    # @param context [Mixed] additional parameters to pass to log; if `tags` is provided it will be included in StatsD
    def submit_event(level, message, stats_key, **context)
      call_location = context[:call_location] || caller_locations.first
      context[:tags] = ((context[:tags] || []) + @tags).uniq

      # claim is not a required field and could be an Integer or SavedClaim
      claim = context[:claim]
      form_id = claim.try(:form_id) || form_id
      claim_id = claim.try(:id) || claim
      confirmation_number = claim.try(:confirmation_number)

      payload = {
        form_id:,
        claim_id:,
        confirmation_number:,
        **context.except(:call_location, :claim)
      }

      track_request(level, message, stats_key, call_location:, **payload)
    end
  end
end
