# frozen_string_literal: true

module Vass
  module V0
    ##
    # AppointmentsController handles appointment availability operations for authenticated veterans.
    #
    # All endpoints require JWT authentication from the OTP authentication flow.
    # The JWT contains the veteran_id which is used to fetch veteran-specific data.
    #
    class AppointmentsController < Vass::ApplicationController
      include Vass::JwtAuthentication
      include Vass::MetricsTracking

      before_action :authenticate_jwt
      before_action :set_appointments_service

      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

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
          track_success(APPOINTMENTS_AVAILABILITY)
        else
          track_availability_scenario(result[:status])
        end

        render_availability_result(result)
      rescue Vass::Errors::VassApiError,
             Vass::Errors::ServiceError,
             Vass::Errors::AuthenticationError,
             Vass::Errors::NotFoundError => e
        track_failure(APPOINTMENTS_AVAILABILITY, error_type: e.class.name)
        raise
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
        response = @appointments_service.get_agent_skills
        agent_skills = response.dig('data', 'agent_skills') || []
        topics = map_agent_skills_to_topics(agent_skills)
        track_success(APPOINTMENTS_TOPICS)
        render_camelized_json({ data: { topics: } })
      rescue Vass::Errors::VassApiError,
             Vass::Errors::ServiceError,
             Vass::Errors::AuthenticationError,
             Vass::Errors::NotFoundError => e
        track_failure(APPOINTMENTS_TOPICS, error_type: e.class.name)
        raise
      end

      ##
      # GET /vass/v0/appointment/:appointment_id
      #
      # Retrieves details for a specific appointment.
      # Requires JWT authentication.
      #
      # @example Response
      #   {
      #     "data": {
      #       "appointmentId": "e61e1a40-1e63-f011-bec2-001dd80351ea",
      #       "startUtc": "2025-12-02T10:00:00Z",
      #       "endUtc": "2025-12-02T10:30:00Z",
      #       "agentId": "353dd0fc-335b-ef11-bfe3-001dd80a9f48",
      #       "agentNickname": "Agent Name",
      #       "appointmentStatusCode": 1,
      #       "appointmentStatus": "Confirmed",
      #       "cohortStartUtc": "2025-12-02T09:00:00Z",
      #       "cohortEndUtc": "2025-12-02T17:00:00Z"
      #     }
      #   }
      #
      def show
        validate_required_params!(:appointment_id)
        appointment_id = params[:appointment_id]

        response = @appointments_service.get_appointment(appointment_id:)
        track_success(APPOINTMENTS_SHOW)
        render_vass_response(
          response,
          success_data: ->(r) { r['data'] },
          error_code: 'appointment_not_found',
          error_message: 'Appointment not found',
          error_status: :not_found
        )
      rescue Vass::Errors::VassApiError,
             Vass::Errors::ServiceError,
             Vass::Errors::AuthenticationError,
             Vass::Errors::NotFoundError => e
        track_failure(APPOINTMENTS_SHOW, error_type: e.class.name)
        raise
      end

      ##
      # POST /vass/v0/appointment/:appointment_id/cancel
      #
      # Cancels a specific appointment.
      # Requires JWT authentication.
      #
      # @example Response
      #   {
      #     "data": {
      #       "appointmentId": "e61e1a40-1e63-f011-bec2-001dd80351ea"
      #     }
      #   }
      #
      def cancel
        validate_required_params!(:appointment_id)
        appointment_id = params[:appointment_id]

        response = @appointments_service.cancel_appointment(appointment_id:)
        track_success(APPOINTMENTS_CANCEL)
        render_vass_response(
          response,
          success_data: { appointmentId: appointment_id },
          error_code: 'cancellation_failed',
          error_message: 'Failed to cancel appointment',
          error_status: :unprocessable_content
        )
      rescue Vass::Errors::VassApiError,
             Vass::Errors::ServiceError,
             Vass::Errors::AuthenticationError,
             Vass::Errors::NotFoundError => e
        track_failure(APPOINTMENTS_CANCEL, error_type: e.class.name)
        raise
      end

      ##
      # POST /vass/v0/appointment
      #
      # Creates/books an appointment for the authenticated veteran.
      # Requires JWT authentication and valid appointment_id from Redis session.
      #
      # @example Request Body (camelCase transformed to snake_case by middleware)
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
        validate_required_params!(:topics, :dt_start_utc, :dt_end_utc)

        appointment_id = retrieve_appointment_id_from_session
        return handle_missing_appointment_id unless appointment_id

        response = save_appointment_with_service(appointment_id)
        track_success(APPOINTMENTS_CREATE)
        render_vass_response(
          response,
          success_data: ->(r) { { appointment_id: r.dig('data', 'appointment_id') } },
          error_code: 'appointment_save_failed',
          error_message: 'Failed to save appointment',
          error_status: :unprocessable_content
        )
      rescue Vass::Errors::VassApiError,
             Vass::Errors::ServiceError,
             Vass::Errors::AuthenticationError,
             Vass::Errors::NotFoundError => e
        track_failure(APPOINTMENTS_CREATE, error_type: e.class.name)
        raise
      end

      private

      ##
      # Tracks infrastructure metrics for availability check scenarios.
      # Different scenarios indicate different operational states:
      # - no_cohorts: Veteran outside all cohort windows
      # - next_cohort: Booking window not yet open
      # - already_booked: Veteran already has appointment in current cohort
      # - no_slots_available: In valid window but zero bookable slots (capacity issue)
      #
      # @param status [Symbol] Result status from get_current_cohort_availability
      #
      def track_availability_scenario(status)
        metric = case status
                 when :available_slots then nil
                 when :no_cohorts then AVAILABILITY_NO_COHORTS
                 when :next_cohort then AVAILABILITY_NEXT_COHORT
                 when :already_booked then AVAILABILITY_ALREADY_BOOKED
                 when :no_slots_available then AVAILABILITY_NO_SLOTS
                 end

        track_infrastructure_metric(metric) if metric
      end

      ##
      # Retrieves appointment_id from Redis booking session.
      # Validates that the booking session exists and contains an appointment_id.
      #
      # @return [String, nil] Appointment ID if found, nil otherwise (renders error)
      #
      def retrieve_appointment_id_from_session
        session_data = redis_client.get_booking_session(veteran_id: @current_veteran_id)
        appointment_id = session_data&.fetch(:appointment_id, nil)

        unless appointment_id
          log_vass_event(action: 'missing_booking_session', vass_uuid: @current_veteran_id, level: :warn,
                         **audit_metadata)
          render_error(
            'missing_session_data',
            'Appointment session not found. Please check availability first.',
            :bad_request
          )
          return nil
        end

        appointment_id
      end

      ##
      # Handles the missing appointment_id scenario by tracking failure metrics.
      #
      def handle_missing_appointment_id
        track_failure(APPOINTMENTS_CREATE, error_type: 'missing_session_data')
      end

      ##
      # Handles missing parameter errors from Rails params.require().
      #
      # @param _exception [ActionController::ParameterMissing] The exception (unused)
      #
      def handle_parameter_missing(_exception)
        render_error('missing_parameter', 'Required parameter is missing', :bad_request)
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
      # Retrieves EDIPI from session data which is stored when JWT is issued.
      # Session is keyed by UUID (one session per veteran).
      #
      def set_appointments_service
        session_data = redis_client.session(uuid: @current_veteran_id)
        edipi = session_data&.fetch(:edipi, nil)

        unless edipi
          log_vass_event(action: 'missing_edipi', vass_uuid: @current_veteran_id, level: :error, **audit_metadata)
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
        params.permit(:correlation_id, :appointment_id, :dt_start_utc, :dt_end_utc, topics: [])
      end

      ##
      # Renders error response.
      #
      # @param code [String] Error code
      # @param detail [String] Error detail
      # @param status [Symbol] HTTP status
      #
      def render_error(code, detail, status)
        render_camelized_json({
                                errors: [
                                  {
                                    code:,
                                    detail:
                                  }
                                ]
                              }, status:)
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
          render_error(error_code, message, :unprocessable_content)
        else
          log_vass_event(action: 'unexpected_availability_status', level: :error, status: status.to_s, **audit_metadata)
          render_error('internal_error', 'An unexpected error occurred', :internal_server_error)
        end
      end

      ##
      # Renders successful response with available appointment slots.
      #
      # @param data [Hash] Appointment data with available slots
      #
      def render_available_slots(data)
        render_camelized_json({
                                data: {
                                  appointment_id: data[:appointment_id],
                                  available_slots: data[:available_slots]
                                }
                              })
      end

      ##
      # Renders conflict response when appointment is already booked.
      #
      # @param data [Hash] Existing appointment data
      #
      def render_already_booked(data)
        render_camelized_json({
                                errors: [{
                                  code: 'appointment_already_booked',
                                  detail: 'already scheduled',
                                  appointment: {
                                    appointment_id: data[:appointment_id],
                                    dt_start_utc: data[:start_utc],
                                    dt_end_utc: data[:end_utc]
                                  }
                                }]
                              }, status: :conflict)
      end

      ##
      # Renders response with next available cohort information.
      #
      # @param data [Hash] Next cohort data
      #
      def render_next_cohort(data)
        next_cohort = data[:next_cohort]

        render_camelized_json({
                                data: {
                                  message: data[:message],
                                  next_cohort: {
                                    cohort_start_utc: next_cohort[:cohort_start_utc],
                                    cohort_end_utc: next_cohort[:cohort_end_utc]
                                  }
                                }
                              })
      end

      ##
      # Maps agent skills from VASS API to topic format expected by frontend.
      #
      # @param agent_skills [Array<Hash>] Agent skills from VASS
      # @return [Array<Hash>] Topics with topic_id and topic_name
      #
      def map_agent_skills_to_topics(agent_skills)
        agent_skills.map do |skill|
          {
            'topic_id' => skill['skill_id'],
            'topic_name' => skill['skill_name']
          }
        end
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
            time_start_utc: permitted_params[:dt_start_utc],
            time_end_utc: permitted_params[:dt_end_utc],
            appointment_id:,
            selected_agent_skills: permitted_params[:topics]
          }
        )
      end

      ##
      # Generic method to render VASS API response.
      # Handles the common pattern of checking success and rendering appropriate response.
      #
      # @param response [Hash] Response from VASS API
      # @param success_data [Hash, Proc] Data to render on success (or proc that returns data)
      # @param error_code [String] Error code for failure case
      # @param error_message [String] Error message for failure case
      # @param error_status [Symbol] HTTP status for failure case
      #
      def render_vass_response(response, success_data:, error_code:, error_message:, error_status:)
        if response['success']
          data = success_data.is_a?(Proc) ? success_data.call(response) : success_data
          render_camelized_json({ data: })
        else
          render_error(error_code, error_message, error_status)
        end
      end
    end
  end
end
