# frozen_string_literal: true

require 'logging/include/controller'
require 'logging/include/benefits_intake'
require 'logging/include/zero_silent_failures'

module Logging
  class BaseMonitor < ::Logging::Monitor
    include Logging::Include::Controller
    include Logging::Include::BenefitsIntake
    include Logging::Include::ZeroSilentFailures

    attr_reader :tags

    def initialize(service)
      super(service)
      @tags = ["form_id:#{form_id}"]
    end

    private

    def message_prefix
      "#{name} #{form_id}"
    end

    # Abstract methods
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

    # Submits an event for tracking with standardized payload structure
    # @see Logging::Monitor#track_request
    #
    # @param level [String|Symbol] The severity level of the event (e.g., :error, :info, :warn)
    # @param message [String] The message describing the event
    # @param stats_key [String] The key used for stats tracking
    # @param **context [Hash] additional parameters to pass to log; if `tags` is provided it will be included in StatsD
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
