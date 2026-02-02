# frozen_string_literal: true

require 'unique_user_events'

module MyHealth
  module V1
    ##
    # Controller for logging unique user metrics events in the MHV Portal.
    # Supports batch processing of multiple events in a single request.
    #
    class UniqueUserMetricsController < ApplicationController
      service_tag 'mhv-metrics'
      before_action :authenticate

      ##
      # Creates unique user metric events for the authenticated user.
      # Processes multiple events in a single batch operation.
      #
      # Events are buffered for asynchronous processing - the response indicates
      # which events were accepted for processing, not whether they are new.
      #
      # @example Request payload
      #   POST /my-health/v1/unique_user_metrics
      #   {
      #     "event_names": ["mhv_landing_page_accessed", "secure_messaging_accessed"]
      #   }
      #
      # @example Success response (202 Accepted)
      #   {
      #     "buffered_events": ["mhv_landing_page_accessed", "secure_messaging_accessed"]
      #   }
      #
      # @example Response when feature disabled (200 OK)
      #   {
      #     "buffered_events": []
      #   }
      #
      def create
        event_names = metrics_params[:event_names]

        # Filter to valid events only
        valid_event_names = event_names.select do |event_name|
          UniqueUserEvents::EventRegistry.valid_event?(event_name)
        end

        # Process all valid events - returns array of event names that were buffered
        buffered_events = UniqueUserEvents.log_events(user: current_user, event_names: valid_event_names)

        # Return 202 Accepted if any events were buffered, otherwise 200 OK
        status_code = buffered_events.any? ? :accepted : :ok
        render json: { buffered_events: }, status: status_code
      end

      private

      ##
      # Strong parameters for the metrics request.
      #
      # @return [ActionController::Parameters] Permitted parameters
      #
      def metrics_params
        params.permit(event_names: [])
      end

      ##
      # Validates input parameters and user authentication.
      #
      # @raise [Common::Exceptions::ParameterMissing] if event_names missing
      # @raise [Common::Exceptions::InvalidFieldValue] if event_names invalid
      #
      def authenticate
        super # Call parent authentication

        # Validate required parameters
        raise Common::Exceptions::ParameterMissing, 'event_names' if params[:event_names].blank?

        # Validate event_names is an array
        unless params[:event_names].is_a?(Array)
          raise Common::Exceptions::InvalidFieldValue.new('event_names', 'must be an array')
        end

        # Validate event_names is not empty
        raise Common::Exceptions::InvalidFieldValue.new('event_names', 'cannot be empty') if params[:event_names].empty?

        # Validate each event name is a non-empty string
        params[:event_names].each do |event_name|
          unless event_name.is_a?(String) && event_name.present?
            raise Common::Exceptions::InvalidFieldValue.new('event_names', 'must contain non-empty strings')
          end
        end
        # NOTE: Event registry validation happens in create() to return 'invalid' status instead of raising error
      end
    end
  end
end
