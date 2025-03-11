# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
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

    ##
    # Creates a draft appointment and fetches all related data needed for the frontend
    #
    # @param referral_id [String] The referral ID to use for the appointment
    # @param pagination_params [Hash] Pagination parameters to use when checking existing appointments
    # @return [Hash] A result hash with the following structure:
    #   - On success: { success: true, data: <appointment_data> }
    #   - On failure: { success: false, error: <error_message>, status: <http_status_code> }
    #
    def create_draft_appointment(referral_id, pagination_params = {})
      begin
        cached_referral_data = redis_client.fetch_referral_attributes(referral_number: referral_id)
        if cached_referral_data.nil?
          Rails.logger.error('VAOS Error fetching referral data from cache', { referral_id: })
          return { success: false, error: 'Unable to retrieve referral data', status: :bad_gateway }
        end

        required_fields = [:provider_id, :appointment_type_id]
        missing_fields = required_fields.select { |field| cached_referral_data[field].nil? }

        unless missing_fields.empty?
          Rails.logger.error('VAOS Missing referral data fields',
                             { referral_id:, missing_fields: })
          return {
            success: false,
            error: "Referral data is incomplete. Missing: #{missing_fields.join(', ')}",
            status: :bad_gateway
          }
        end

        referral_check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)
        if referral_check[:error]
          Rails.logger.error('VAOS Error checking appointments', { failures: referral_check[:failures] })
          return {
            success: false,
            error: "Error checking appointments: #{referral_check[:failures]}",
            status: :bad_gateway
          }
        elsif referral_check[:exists]
          Rails.logger.info('VAOS Referral already used', { referral_id: })
          return {
            success: false,
            error: 'No new appointment created: referral is already used',
            status: :unprocessable_entity
          }
        end

        begin
          draft_appointment = persist_draft_appointment(referral_id:)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error('VAOS Error creating draft appointment',
                             { referral_id:, error: e.message })
          return { success: false, error: 'Error creating draft appointment', status: :bad_request }
        end

        begin
          provider = provider_services.get_provider_service(provider_id: cached_referral_data[:provider_id])
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error('VAOS Error fetching provider data',
                             { referral_id:, error: e.message })
          return { success: false, error: 'Error fetching provider data', status: :not_found }
        end

        begin
          slots = fetch_provider_slots(cached_referral_data)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error('VAOS Error fetching provider slots',
                             { referral_id:, error: e.message })
          return { success: false, error: 'Error fetching provider slots', status: :bad_request }
        end

        begin
          drive_time = fetch_drive_times(provider)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error('VAOS Error fetching drive times',
                             { referral_id:, error: e.message })
          return { success: false, error: 'Error fetching drive times', status: :bad_request }
        end

        response_data = OpenStruct.new(
          id: draft_appointment.id,
          provider:,
          slots:,
          drive_time:
        )

        { success: true, data: response_data }
      rescue Common::Exceptions::BackendServiceException => e
        status = e.status
        Rails.logger.error('VAOS Backend service error', { referral_id:, error: e.message, status: })

        mapped_status = case status
                        when 400
                          :bad_request
                        when 404
                          :not_found
                        else
                          :bad_gateway
                        end

        { success: false, error: e.message, status: mapped_status }
      rescue => e
        Rails.logger.error('VAOS Error creating draft appointment', { referral_id:, error: e.message })
        { success: false, error: 'Error creating draft appointment', status: :internal_server_error }
      end
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
    # @return OpenStruct response from EPS submit appointment endpoint
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

    ##
    # Create a draft appointment in EPS by making an API call to the EPS endpoint
    #
    # @param referral_id [String] The referral ID to use for the appointment
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def persist_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Merge provider data with appointment data
    #
    # @param appointments [Array<Hash>] Array of appointment data
    # @raise [Common::Exceptions::BackendServiceException] If provider data cannot be fetched
    # @return [Array<Hash>] Array of appointment data with provider data merged in
    def merge_provider_data_with_appointments(appointments)
      return [] if appointments.nil?

      provider_ids = appointments.pluck(:provider_service_id).compact.uniq
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

    ##
    # Get instance of ProviderService
    #
    # @return [Eps::ProviderService] ProviderService instance
    def provider_services
      @provider_services ||= Eps::ProviderService.new(user)
    end

    ##
    # Fetches slots from provider based on referral data
    #
    # @param referral_data [Hash] The referral data containing provider_id and appointment_type_id
    # @return [Array<Hash>] Array of available slots
    #
    def fetch_provider_slots(referral_data)
      provider_services.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )
    end

    ##
    # Calculates drive times between user's address and provider location
    #
    # @param provider [OpenStruct] The provider data containing location information
    # @return [Hash, nil] Drive time data or nil if user address is incomplete
    #
    def fetch_drive_times(provider)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address.longitude

      provider_services.get_drive_times(
        destinations: {
          provider.id => {
            latitude: provider.location[:latitude],
            longitude: provider.location[:longitude]
          }
        },
        origin: {
          latitude: user_address.latitude,
          longitude: user_address.longitude
        }
      )
    end

    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    def appointments_service
      @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
    end
  end
end
