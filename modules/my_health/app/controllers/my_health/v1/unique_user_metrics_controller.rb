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
      # @example Request payload
      #   POST /my-health/v1/unique_user_metrics
      #   {
      #     "event_names": ["mhv_landing_page_accessed", "secure_messaging_accessed"]
      #   }
      #
      # @example Success response when feature enabled (200 OK or 201 Created)
      #   {
      #     "results": [
      #       { "event_name": "mhv_landing_page_accessed", "status": "created", "new_event": true },
      #       { "event_name": "secure_messaging_accessed", "status": "exists", "new_event": false }
      #     ]
      #   }
      #
      # @example Success response when feature disabled (200 OK)
      #   {
      #     "results": [
      #       { "event_name": "mhv_landing_page_accessed", "status": "disabled", "new_event": false },
      #       { "event_name": "secure_messaging_accessed", "status": "disabled", "new_event": false }
      #     ]
      #   }
      #
      def create
        event_names = metrics_params[:event_names]

        # Process all events and collect results
        results = event_names.flat_map do |event_name|
          UniqueUserEvents.log_event(user: current_user, event_name:)
        end

        # Return 201 if any new events were logged, otherwise 200
        new_events_count = results.count { |result| result[:new_event] }
        status_code = new_events_count.positive? ? :created : :ok
        render json: { results: }, status: status_code
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

        # Validate each event name is a non-empty string and in the registry
        params[:event_names].each do |event_name|
          unless event_name.is_a?(String) && event_name.present?
            raise Common::Exceptions::InvalidFieldValue.new('event_names', 'must contain non-empty strings')
          end

          unless UniqueUserEvents::EventRegistry.valid_event?(event_name)
            raise Common::Exceptions::InvalidFieldValue.new('event_names',
                                                            "contains invalid event: '#{event_name}'. " \
                                                            'Use EventRegistry constants.')
          end
        end
      end
    end
  end
end
