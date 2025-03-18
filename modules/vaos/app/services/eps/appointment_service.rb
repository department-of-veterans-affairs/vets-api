# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    CACHE_ERROR_MSG = 'Error fetching referral data from cache'
    DRIVE_TIME_ERROR_MSG = 'Invalid coordinates for drive time calculation'
    PROVIDER_ERROR_MSG = 'Error fetching provider information'
    PROVIDER_SLOTS_ERROR_MSG = 'Error fetching provider slots'
    DRAFT_APPOINTMENT_ERROR_MSG = 'Error creating draft appointment'

    ##
    # Get a specific appointment from EPS by ID
    #
    # @param appointment_id [String] The ID of the appointment to retrieve
    # @param retrieve_latest_details [Boolean] Whether to fetch latest details from provider service
    # @raise [ArgumentError] If appointment_id is blank
    # @return OpenStruct response from EPS get appointment endpoint
    #
    def get_appointment(appointment_id:, retrieve_latest_details: false)
      query_params = retrieve_latest_details ? '?retrieveLatestDetails=true' : ''

      response = perform(:get, "/#{config.base_path}/appointments/#{appointment_id}#{query_params}", {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments
      response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                         {}, headers)
      appointments = response.body[:appointments]
      merged_appointments = merge_provider_data_with_appointments(appointments)
      OpenStruct.new(data: merged_appointments)
    end

    def create_draft_appointment_with_response(referral_id:, user_coordinates:, pagination_params: {})
      validation_result = create_draft_appointment_with_validation(
        referral_id:,
        pagination_params:
      )

      return validation_result unless validation_result[:success]

      build_draft_appointment_response(
        validation_result[:draft_appointment],
        validation_result[:referral_data],
        user_coordinates
      )
    end

    ##
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
    # @return [OpenStruct] response from EPS submit appointment endpoint
    #
    def submit_appointment(appointment_id, params = {})
      raise ArgumentError, 'appointment_id is required and cannot be blank' if appointment_id.blank?

      required_params = %i[network_id provider_service_id slot_ids referral_number]
      missing_params = required_params - params.keys

      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

      payload = build_submit_payload(params)

      response = perform(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", payload, headers)
      OpenStruct.new(response.body)
    end

    private

    def submit_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Draft appointment error: #{e.message}")
      build_error_response(DRAFT_APPOINTMENT_ERROR_MSG, "Unable to create draft appointment: #{e.message}",
                           :bad_request)
    rescue => e
      Rails.logger.error("Draft appointment error: #{e.message}")
      build_error_response(DRAFT_APPOINTMENT_ERROR_MSG, "Unexpected error creating draft appointment: #{e.message}",
                           :bad_request)
    end

    def build_error_response(title, detail, status, stats_key = nil)
      StatsD.increment(stats_key) if stats_key.present?

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title:,
            detail:
          }]
        },
        status:
      }
    end

    def merge_provider_data_with_appointments(appointments)
      return [] if appointments.nil?

      provider_ids = appointments.pluck(:provider_service_id).compact.uniq
      providers = provider_service.get_provider_services_by_ids(provider_ids:)

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
        payload[:additional_patient_attributes] =
          params[:additional_patient_attributes]
      end

      payload
    end

    def provider_service
      @provider_service ||= Eps::ProviderService.new(user)
    end

    def appointments_service
      @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
    end

    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    def create_draft_appointment_with_validation(referral_id:, pagination_params: {})
      referral_data = fetch_referral_attributes(referral_number: referral_id)
      return referral_data if referral_data.is_a?(Hash) && referral_data[:error]

      validation_result = build_referral_validation_response(referral_data)
      return validation_result unless validation_result[:success]

      usage_result = check_referral_usage(referral_id, pagination_params)
      return usage_result unless usage_result[:success]

      draft_appointment = submit_draft_appointment(referral_id:)
      return draft_appointment if draft_appointment.is_a?(Hash) && draft_appointment[:error]

      {
        success: true,
        draft_appointment:,
        referral_data:
      }
    end

    def validate_referral_data(referral_data)
      return { valid: false, missing_attributes: ['all required attributes'] } if referral_data.nil?

      required_attributes = %i[provider_id appointment_type_id start_date end_date]
      missing_attributes = required_attributes.select { |attr| referral_data[attr].blank? }

      {
        valid: missing_attributes.empty?,
        missing_attributes: missing_attributes.map(&:to_s)
      }
    end

    def build_referral_validation_response(referral_data)
      validation_result = validate_referral_data(referral_data)
      if validation_result[:valid]
        { success: true }
      else
        build_error_response(
          'Invalid referral data',
          "Required referral data is missing or incomplete: #{validation_result[:missing_attributes].join(', ')}",
          :unprocessable_entity
        )
      end
    end

    def check_referral_usage(referral_id, pagination_params = {})
      check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

      if check[:error]
        build_error_response(
          'Error checking appointments',
          "Error checking if referral is already used: #{check[:failures]}",
          :bad_gateway
        )
      elsif check[:exists]
        build_error_response(
          'Referral already used',
          'No new appointment created: referral is already used',
          :unprocessable_entity
        )
      else
        { success: true }
      end
    end

    def fetch_referral_attributes(referral_number:)
      redis_client.fetch_referral_attributes(referral_number:)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error: #{e.message}")
      build_error_response(
        CACHE_ERROR_MSG,
        "Unable to connect to cache service: #{e.message}",
        :bad_gateway,
        'api.vaos.va_mobile.response.partial.redis_error'
      )
    end

    def fetch_provider_slots(referral_data)
      provider_service.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )
    rescue => e
      status = e.respond_to?(:status) ? e.status : :bad_gateway
      Rails.logger.error("Provider slots error: #{e.message}")
      build_error_response(
        PROVIDER_SLOTS_ERROR_MSG,
        "Unexpected error fetching provider slots: #{e.message}",
        status,
        'api.vaos.va_mobile.response.partial.provider_slots_error'
      )
    end

    def get_provider_service(provider_id:)
      provider_service.get_provider_service(provider_id:)
    rescue => e
      Rails.logger.error("Provider service error: #{e.message}")
      build_error_response(PROVIDER_ERROR_MSG, "Unexpected error fetching provider information: #{e.message}",
                           :not_found)
    end

    def get_drive_times(provider, user_coordinates)
      return nil unless user_coordinates[:latitude] && user_coordinates[:longitude]

      provider_service.get_drive_times(
        destinations: {
          provider.id => { latitude: provider.location[:latitude], longitude: provider.location[:longitude] }
        },
        origin: { latitude: user_coordinates[:latitude], longitude: user_coordinates[:longitude] }
      )
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Drive times error: #{e.message}")
      status = e.status == 400 ? :bad_request : nil
      build_error_response(DRIVE_TIME_ERROR_MSG, "Invalid coordinates for drive time calculation: #{e.message}",
                           status || :bad_request)
    rescue => e
      Rails.logger.error("Drive times error: #{e.message}")
      build_error_response(DRIVE_TIME_ERROR_MSG, "Unexpected error calculating drive times: #{e.message}", :bad_request)
    end

    def build_draft_appointment_response(draft_appointment, referral_data, user_coordinates)
      provider = get_provider_service(provider_id: referral_data[:provider_id])
      return provider if provider.is_a?(Hash) && provider[:error]

      slots = fetch_provider_slots(referral_data)
      return slots if slots.is_a?(Hash) && slots[:error]

      drive_time = get_drive_times(provider, user_coordinates)
      return drive_time if drive_time.is_a?(Hash) && drive_time[:error]

      OpenStruct.new(
        id: draft_appointment.id,
        provider:,
        slots:,
        drive_time:
      )
    end
  end
end
