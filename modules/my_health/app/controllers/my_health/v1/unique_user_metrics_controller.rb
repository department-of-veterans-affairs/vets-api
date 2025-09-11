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
      before_action :check_feature_enabled

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
      # @example Success response (200 OK or 201 Created)
      #   {
      #     "results": [
      #       { "event_name": "mhv_landing_page_accessed", "status": "created", "new_event": true },
      #       { "event_name": "secure_messaging_accessed", "status": "exists", "new_event": false }
      #     ]
      #   }
      #
      def create
        user_id = current_user.user_account_uuid
        event_names = metrics_params[:event_names]

        # Process all events and collect results
        results = event_names.map do |event_name|
          process_single_event(user_id, event_name)
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
      # Processes a single event and returns result information.
      #
      # @param user_id [String] UUID of the authenticated user
      # @param event_name [String] Name of the event to log
      # @return [Hash] Result hash with event_name, status, and new_event flag
      #
      def process_single_event(user_id, event_name)
        was_new_event = UniqueUserEvents.log_event(user_id:, event_name:)

        {
          event_name:,
          status: was_new_event ? 'created' : 'exists',
          new_event: was_new_event
        }
      rescue => e
        Rails.logger.error(
          'UUM: Failed to process event in controller',
          { user_id:, event_name:, error: e.message }
        )

        {
          event_name:,
          status: 'error',
          new_event: false,
          error: 'Failed to process event'
        }
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
      end

      ##
      # Validates that the feature flag is enabled.
      #
      # @raise [Common::Exceptions::NotImplemented] if feature is disabled
      #
      def check_feature_enabled
        return if Flipper.enabled?(:unique_user_metrics_logging)

        raise Common::Exceptions::NotImplemented,
              detail: 'Unique user metrics logging is not currently available'
      end
    end
  end
end
