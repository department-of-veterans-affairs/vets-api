# frozen_string_literal: true

module Vass
  module V0
    ##
    # AppointmentsController handles appointment availability operations for authenticated veterans.
    #
    # All endpoints require JWT authentication from the OTC authentication flow.
    # The JWT contains the veteran_id which is used to fetch veteran-specific data.
    #
    class AppointmentsController < Vass::ApplicationController
      include Vass::JwtAuthentication

      before_action :authenticate_jwt
      before_action :set_appointments_service

      ##
      # GET /vass/v0/appointment-availability
      #
      # Returns available appointment slots for the veteran's current cohort.
      # Stores appointmentId in Redis for subsequent booking steps.
      #
      def availability
        result = @appointments_service.get_current_cohort_availability(veteran_id: @current_veteran_id)

        if result[:status] == :available_slots
          redis_client.store_booking_session(
            veteran_id: @current_veteran_id,
            data: { appointment_id: result[:data][:appointment_id] }
          )
        end

        render_availability_result(result)
      rescue Vass::Errors::VassApiError => e
        handle_vass_error(e, 'get_availability')
      rescue Vass::Errors::ServiceError => e
        handle_service_error(e, 'get_availability')
      rescue => e
        handle_unexpected_error(e, 'get_availability')
      end

      private

      ##
      # Returns a Redis client instance.
      #
      # @return [Vass::RedisClient] Redis client
      #
      def redis_client
        @redis_client ||= Vass::RedisClient.build
      end

      ##
      # Sets up the appointments service with veteran EDIPI.
      #
      # For appointments endpoints, we need the EDIPI which should be
      # stored in Redis during OTC authentication flow.
      #
      def set_appointments_service
        veteran_metadata = redis_client.veteran_metadata(uuid: @current_veteran_id)
        edipi = veteran_metadata&.fetch(:edipi, nil)

        unless edipi
          render_error('missing_edipi', 'Veteran EDIPI not found. Please re-authenticate.', :unauthorized)
          return
        end

        @appointments_service = Vass::AppointmentsService.build(
          edipi:,
          correlation_id: permitted_params[:correlation_id]
        )
      end

      ##
      # Permits and extracts request parameters.
      #
      # @return [ActionController::Parameters] Permitted parameters
      #
      def permitted_params
        params.permit(:correlation_id)
      end

      ##
      # Handles VASS API errors.
      #
      # @param error [Vass::Errors::VassApiError] VASS API error
      # @param action [String] Action name
      #
      def handle_vass_error(error, action)
        log_error(error, action)
        render_error('vass_api_error', 'External service error', :bad_gateway)
      end

      ##
      # Handles service errors (timeouts, network issues).
      #
      # @param error [Vass::Errors::ServiceError] Service error
      # @param action [String] Action name
      #
      def handle_service_error(error, action)
        log_error(error, action)
        render_error('service_error', 'Unable to process request with appointment service', :service_unavailable)
      end

      ##
      # Handles unexpected errors.
      #
      # @param error [StandardError] Unexpected error
      # @param action [String] Action name
      #
      def handle_unexpected_error(error, action)
        log_error(error, action)
        render_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      ##
      # Logs error information without PHI.
      #
      # @param error [Exception] Error object
      # @param action [String] Action name
      #
      def log_error(error, action)
        Rails.logger.error({
          service: 'vass',
          controller: 'appointments',
          action:,
          error_class: error.class.name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Renders error response.
      #
      # @param code [String] Error code
      # @param detail [String] Error detail
      # @param status [Symbol] HTTP status
      #
      def render_error(code, detail, status)
        render json: {
          errors: [
            {
              code:,
              detail:
            }
          ]
        }, status:
      end

      ##
      # Renders availability result based on service layer response.
      #
      # @param result [Hash] Result from AppointmentsService#get_current_cohort_availability
      #
      def render_availability_result(result)
        status = result[:status]
        data = result[:data]

        case status
        when :available_slots then render_available_slots(data)
        when :already_booked then render_already_booked(data)
        when :next_cohort then render_next_cohort(data)
        when :no_cohorts then render_no_cohorts(data)
        when :no_slots_available then render_no_slots_available(data)
        end
      end

      def render_available_slots(data)
        render_success(
          appointmentId: data[:appointment_id],
          availableSlots: data[:available_slots]
        )
      end

      def render_already_booked(data)
        render_error_with_data(
          'appointment_already_booked',
          'already scheduled',
          :conflict,
          appointment: {
            appointmentId: data[:appointment_id],
            dtStartUTC: data[:start_utc],
            dtEndUTC: data[:end_utc]
          }
        )
      end

      def render_next_cohort(data)
        next_cohort = data[:next_cohort]

        render_success(
          message: data[:message],
          nextCohort: {
            cohortStartUtc: next_cohort[:cohort_start_utc],
            cohortEndUtc: next_cohort[:cohort_end_utc]
          }
        )
      end

      def render_no_cohorts(data)
        render_error('not_within_cohort', data[:message], :unprocessable_entity)
      end

      def render_no_slots_available(data)
        render_error('no_slots_available', data[:message], :unprocessable_entity)
      end

      def render_success(data)
        render json: { data: }, status: :ok
      end

      def render_error_with_data(code, detail, status, **additional)
        render json: { errors: [{ code:, detail: }.merge(additional)] }, status:
      end
    end
  end
end
