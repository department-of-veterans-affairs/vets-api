# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    ##
    # Get a specific appointment from EPS by ID
    #
    # @param appointment_id [String] The ID of the appointment to retrieve
    # @param retrieve_latest_details [Boolean] Whether to fetch latest details from provider service
    # @raise [ArgumentError] If appointment_id is blank
    # @raise [Eps::ServiceException] If response contains error field
    # @return OpenStruct response from EPS get appointment endpoint
    #
    def get_appointment(appointment_id:, retrieve_latest_details: false)
      query_params = retrieve_latest_details ? '?retrieveLatestDetails=true' : ''

      with_monitoring do
        response = perform(:get, "/#{config.base_path}/appointments/#{appointment_id}#{query_params}", {},
                           request_headers_with_correlation_id)
        result = OpenStruct.new(response.body)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(result, response, 'get_appointment')

        result
      end
    rescue Eps::ServiceException => e
      handle_eps_error!(e, 'get_appointment')
      raise
    rescue => e
      log_sanitized_error(e, 'get_appointment')
      raise
    end

    ##
    # Get appointments data from EPS
    #
    # @param referral_number [String] Optional referral number to filter appointments
    # @return [Array<Hash>] Array of appointment hashes from EPS
    #
    def get_appointments(referral_number: nil)
      params = { patientId: patient_id }
      params[:referralNumber] = referral_number if referral_number.present?

      query_string = URI.encode_www_form(params)

      with_monitoring do
        response = perform(:get, "/#{config.base_path}/appointments?#{query_string}",
                           {}, request_headers_with_correlation_id)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(response.body, response, 'get_appointments')
        return [] unless response.body.is_a?(Hash)

        appointments = response.body[:appointments]
        return [] unless appointments.is_a?(Array)

        appointments
      end
    rescue Eps::ServiceException => e
      handle_eps_error!(e, 'get_appointments')
      raise
    rescue => e
      log_sanitized_error(e, 'get_appointments')
      raise
    end

    ##
    # Get appointments data from EPS with provider information and return as EpsAppointment objects
    #
    # @return [Array<VAOS::V2::EpsAppointment>] Array of EpsAppointment objects with provider data
    #
    def get_appointments_with_providers
      appointments = get_appointments
      return [] if appointments.blank?

      merged_appointments = merge_provider_data_with_appointments(appointments)
      merged_appointments.map { |appt| VAOS::V2::EpsAppointment.new(appt, appt[:provider]) }
    end

    ##
    # Create draft appointment in EPS
    #
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def create_draft_appointment(referral_id:)
      with_monitoring do
        response = perform(:post, "/#{config.base_path}/appointments",
                           { patientId: patient_id, referral: { referralNumber: referral_id } },
                           request_headers_with_correlation_id)

        result = OpenStruct.new(response.body)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(result, response, 'create_draft_appointment')

        result
      end
    rescue Eps::ServiceException => e
      handle_eps_error!(e, 'create_draft_appointment')
      raise
    rescue => e
      log_sanitized_error(e, 'create_draft_appointment')
      raise
    end

    ##
    #
    # Submit an appointment to EPS for booking
    #
    # @param appointment_id [String] The ID of the appointment to submit
    # @param params [Hash] Hash containing required and optional parameters
    # @option params [String] :network_id The network ID for the appointment
    # @option params [String] :provider_service_id The provider service ID
    # @option params [Array<String>] :slot_ids Array of slot IDs for the appointment
    # @option params [String] :referral_number The referral number
    # @option params [Hash] :additional_patient_attributes Optional patient details (address, contact info)
    # @raise [ArgumentError] If any required parameters are missing
    # @raise [Eps::ServiceException] If response contains error field
    # @return OpenStruct response from EPS submit appointment endpoint
    #
    def submit_appointment(appointment_id, params = {})
      validate_submit_params!(appointment_id, params)
      payload = build_submit_payload(params)
      persist_submit_side_effects(appointment_id)

      with_monitoring do
        response = perform(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", payload,
                           request_headers_with_correlation_id)

        result = OpenStruct.new(response.body)
        check_for_eps_error!(result, response, 'submit_appointment')
        result
      end
    rescue Eps::ServiceException => e
      handle_eps_error!(e, 'submit_appointment')
      raise
    rescue => e
      log_sanitized_error(e, 'submit_appointment')
      raise
    end

    private

    ##
    # Merge provider data with appointment data
    #
    # @param appointments [Array<Hash>] Array of appointment data
    # @raise [Common::Exceptions::BackendServiceException] If provider data cannot be fetched
    # @return [Array<Hash>] Array of appointment data with provider data merged in
    def merge_provider_data_with_appointments(appointments)
      return [] if appointments.nil?

      provider_ids = appointments.pluck(:provider_service_id).compact.uniq
      return appointments if provider_ids.empty?

      providers = provider_services.get_provider_services_by_ids(provider_ids:)

      appointments.each do |appointment|
        next unless appointment[:provider_service_id]

        provider = providers[:provider_services].find do |provider_data|
          provider_data[:id] == appointment[:provider_service_id]
        end
        appointment[:provider] = provider
      end

      appointments
    end

    def build_submit_payload(params)
      payload = {
        network_id: params[:network_id],
        provider_service_id: params[:provider_service_id],
        slot_ids: params[:slot_ids],
        referral: {
          referral_number: params[:referral_number]
        }
      }

      if params[:additional_patient_attributes]
        payload[:additional_patient_attributes] = params[:additional_patient_attributes]
      end

      payload
    end

    def validate_submit_params!(appointment_id, params)
      raise ArgumentError, 'appointment_id is required and cannot be blank' if appointment_id.blank?
      raise ArgumentError, 'Email is required' if user.email.blank?

      required_params = %i[network_id provider_service_id slot_ids referral_number]
      missing_params = required_params - params.keys
      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?
    end

    def persist_submit_side_effects(appointment_id)
      redis_client.store_appointment_data(
        uuid: user.uuid,
        appointment_id:,
        email: user.email
      )

      appointment_last4 = appointment_id.to_s.last(4)
      Eps::AppointmentStatusJob.perform_async(user.uuid, appointment_last4)
    end

    ##
    # Get instance of ProviderService
    #
    # @return [Eps::ProviderService] ProviderService instance
    def provider_services
      @provider_services ||= Eps::ProviderService.new(user)
    end

    ##
    # Get instance of RedisClient
    #
    # @return [Eps::RedisClient] RedisClient instance
    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    ##
    # Logs error with sanitized PII (removes ICN and referral numbers)
    #
    # @param error [StandardError] The error to log
    # @param method_name [String] The calling method name for logging context
    # @return [void]
    def log_sanitized_error(error, method_name)
      sanitized_message = sanitize_error_message(error.message)

      error_context = {
        service: 'EPS',
        method: method_name,
        error_class: error.class.name,
        error_message: sanitized_message,
        backtrace: error.backtrace&.first(5), # Include first 5 lines of backtrace for debugging
        timestamp: Time.current.iso8601,
        controller: controller_name,
        station_number:,
        eps_trace_id:
      }.compact

      Rails.logger.error("#{CC_APPOINTMENTS}: EPS unexpected error", error_context)
    end

    ##
    # Sanitizes error message by removing ICN and referral numbers
    #
    # @param message [String] The error message to sanitize
    # @return [String] Sanitized error message
    def sanitize_error_message(message)
      return nil if message.nil?

      sanitized = message.dup

      # Remove ICNs using existing VAOS anonymizer
      sanitized = VAOS::Anonymizers.anonymize_icns(sanitized)

      # Remove referral numbers - these can have various formats:
      # - VA followed by numbers (e.g., VA0000005681)
      # - REF- followed by alphanumeric (e.g., REF-12345, ref-124)
      # - referralNumber with values in quotes or after =
      # Pattern matches common referral number formats
      sanitized.gsub!(/\bVA\d{10}\b/, '[REFERRAL_REDACTED]')
      sanitized.gsub!(/\bREF-[\w\d]+\b/i, '[REFERRAL_REDACTED]')
      sanitized.gsub!(/referralNumber["\s:=]+[\w\d-]+/i, 'referralNumber=[REFERRAL_REDACTED]')
      sanitized.gsub!(/referral_number["\s:=]+[\w\d-]+/i, 'referral_number=[REFERRAL_REDACTED]')

      sanitized
    end

    ##
    # Returns the controller name from RequestStore for logging context
    #
    # @return [String, nil] The controller name or nil if not set
    def controller_name
      RequestStore.store['controller_name']
    end

    ##
    # Returns the user's primary station number for logging context
    #
    # @return [String, nil] The station number or nil if not available
    def station_number
      user&.va_treatment_facility_ids&.first
    end

    ##
    # Returns the EPS trace ID from RequestStore
    #
    # @return [String, nil] The trace ID or nil if not set
    def eps_trace_id
      RequestStore.store['eps_trace_id']
    end
  end
end
