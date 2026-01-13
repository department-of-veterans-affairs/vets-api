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

      rescue_from Vass::Errors::ServiceError, with: :handle_service_error
      rescue_from Vass::Errors::VassApiError, with: :handle_vass_api_error

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
      end

      ##
      # GET /vass/v0/topics
      #
      # Returns available appointment topics (agent skills from VASS).
      # Requires JWT authentication.
      #
      # @example Response
      #   {
      #     "data": {
      #       "topics": [
      #         {
      #           "topicId": "67e0bd9f-5e53-f011-bec2-001dd806389e",
      #           "topicName": "General Support"
      #         }
      #       ]
      #     }
      #   }
      #
      def topics
        topics_list = @appointments_service.get_agent_skills || []
        render json: { data: { topics: topics_list } }, status: :ok
      end

      ##
      # POST /vass/v0/appointment
      #
      # Creates/books an appointment for the authenticated veteran.
      # Requires JWT authentication and valid appointment_id from Redis session.
      #
      # @example Request Body
      #   {
      #     "topics": ["67e0bd9f-5e53-f011-bec2-001dd806389e", "78f1ce0a-6f64-g122-cfd3-112ee917462f"],
      #     "dtStartUtc": "2026-01-10T10:00:00Z",
      #     "dtEndUtc": "2026-01-10T10:30:00Z"
      #   }
      #
      # @example Response
      #   {
      #     "data": {
      #       "appointmentId": "e61e1a40-1e63-f011-bec2-001dd80351ea"
      #     }
      #   }
      #
      def create
        return unless validate_appointment_creation_params!

        session_data = redis_client.get_booking_session(veteran_id: @current_veteran_id)
        appointment_id = session_data&.fetch(:appointment_id, nil)

        response = save_appointment_with_service(appointment_id)
        render_appointment_creation_response(response)
      end

      private

      ##
      # Handles VASS API errors.
      #
      # @param exception [Vass::Errors::VassApiError] The exception
      #
      def handle_vass_api_error(exception)
        handle_error(exception, 'vass_api_error', 'External service error', :bad_gateway)
      end

      ##
      # Handles service errors (timeouts, network issues).
      #
      # @param exception [Vass::Errors::ServiceError] The exception
      #
      def handle_service_error(exception)
        handle_error(
          exception,
          'service_error',
          'Unable to process request with appointment service',
          :service_unavailable
        )
      end

      ##
      # Validates required parameters for appointment creation per API spec.
      # Error codes and messages match the external API contract.
      #
      # @return [Boolean] true if valid, false if invalid (and error is rendered)
      # @see https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/appointments/va-online-scheduling/initiatives/solid-start-scheduling/engineering/api-specification.md
      #
      def validate_appointment_creation_params!
        required_params = [
          { key: :topics, error_code: 'missing_topics', message: 'Topics are required' },
          { key: :dtStartUtc, error_code: 'missing_start_time', message: 'Start time is required' },
          { key: :dtEndUtc, error_code: 'missing_end_time', message: 'End time is required' }
        ]

        required_params.each do |param|
          next if permitted_params[param[:key]].present?

          render_error(param[:error_code], param[:message], :bad_request)
          return false
        end

        true
      end

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
          return render_error('missing_edipi', 'Veteran EDIPI not found. Please re-authenticate.', :unauthorized)
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
        params.permit(:correlation_id, :dtStartUtc, :dtEndUtc, topics: [])
      end

      ##
      # Handles errors by logging and rendering appropriate response.
      #
      # @param error [Exception] Error object
      # @param code [String] Error code
      # @param detail [String] Error detail message
      # @param status [Symbol] HTTP status
      #
      def handle_error(error, code, detail, status)
        Rails.logger.error({
          service: 'vass',
          controller: 'appointments',
          action: action_name,
          error_class: error.class.name,
          timestamp: Time.current.iso8601
        }.to_json)

        render_error(code, detail, status)
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
        when :no_cohorts, :no_slots_available
          message = data[:message]
          error_code = status == :no_cohorts ? 'not_within_cohort' : 'no_slots_available'
          render_error(error_code, message, :unprocessable_entity)
        else
          Rails.logger.error("Unexpected availability status: #{status}")
          render_error('internal_error', 'An unexpected error occurred', :internal_server_error)
        end
      end

      ##
      # Renders successful response with available appointment slots.
      #
      # @param data [Hash] Appointment data with available slots
      #
      def render_available_slots(data)
        render json: {
          data: {
            appointmentId: data[:appointment_id],
            availableSlots: data[:available_slots]
          }
        }, status: :ok
      end

      ##
      # Renders conflict response when appointment is already booked.
      #
      # @param data [Hash] Existing appointment data
      #
      def render_already_booked(data)
        render json: {
          errors: [{
            code: 'appointment_already_booked',
            detail: 'already scheduled',
            appointment: {
              appointmentId: data[:appointment_id],
              dtStartUTC: data[:start_utc],
              dtEndUTC: data[:end_utc]
            }
          }]
        }, status: :conflict
      end

      ##
      # Renders response with next available cohort information.
      #
      # @param data [Hash] Next cohort data
      #
      def render_next_cohort(data)
        next_cohort = data[:next_cohort]

        render json: {
          data: {
            message: data[:message],
            nextCohort: {
              cohortStartUtc: next_cohort[:cohort_start_utc],
              cohortEndUtc: next_cohort[:cohort_end_utc]
            }
          }
        }, status: :ok
      end

      ##
      # Saves appointment via service layer.
      #
      # @param appointment_id [String] Appointment ID from session
      # @return [Hash] Response from VASS API
      #
      def save_appointment_with_service(appointment_id)
        @appointments_service.save_appointment(
          appointment_params: {
            veteran_id: @current_veteran_id,
            time_start_utc: permitted_params[:dtStartUtc],
            time_end_utc: permitted_params[:dtEndUtc],
            appointment_id:,
            selected_agent_skills: permitted_params[:topics]
          }
        )
      end

      ##
      # Renders appointment creation response.
      #
      # @param response [Hash] Response from VASS API save_appointment call
      #
      def render_appointment_creation_response(response)
        if response['success']
          appointment_id = response.dig('data', 'appointmentId')
          render json: { data: { appointmentId: appointment_id } }, status: :ok
        else
          render_error('appointment_save_failed', 'Failed to save appointment', :unprocessable_entity)
        end
      end
    end
  end
end
