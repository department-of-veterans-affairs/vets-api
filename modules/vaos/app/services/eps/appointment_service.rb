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
      appointments = response.body['appointments']
      merged_appointments = merge_provider_data_with_appointments(appointments)
      OpenStruct.new(data: merged_appointments)
    end

    ##
    # Create draft appointment in EPS
    #
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def create_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
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

    def merge_provider_data_with_appointments(appointments)
      provider_ids = appointments.map { |appointment| appointment['providerServiceId'] }.compact.uniq
      providers = provider_services.get_provider_services_by_ids(provider_ids: provider_ids)

      appointments.each do |appointment|
        next unless appointment['providerServiceId']

        provider = providers['providerServices'].find { |provider_data| provider_data['id'] == appointment['providerServiceId'] }
        appointment['provider'] = provider
      end

      appointments
    end

    def build_submit_payload(params)
      payload = {
        networkId: params[:network_id],
        providerServiceId: params[:provider_service_id],
        slotIds: params[:slot_ids],
        referral: {
          referralNumber: params[:referral_number]
        }
      }

      if params[:additional_patient_attributes]
        payload[:additionalPatientAttributes] = params[:additional_patient_attributes]
      end

      payload
    end

    def provider_services
      @provider_services ||= Eps::ProviderService.new(user)
    end
  end
end
