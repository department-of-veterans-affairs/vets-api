# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointment
      attr_reader :id, :status, :patient_icn, :created, :location_id, :clinic,
                  :start, :is_latest, :last_retrieved, :contact, :referral_id,
                  :referral, :provider_service_id, :provider_name,
                  :provider, :type_of_care, :provider_phone, :referring_facility_details

      def initialize(appointment_data = {}, referral = nil, provider = nil)
        appointment_details = appointment_data[:appointment_details]
        referral_details = appointment_data[:referral]

        @id = appointment_data[:id]&.to_s
        @status = determine_status(appointment_details[:status])
        @patient_icn = appointment_data[:patient_id]
        @created = appointment_details[:last_retrieved]
        @location_id = appointment_data[:network_id]
        @clinic = appointment_data[:provider_service_id]
        @start = appointment_data.dig(:appointment_details, :start)
        @is_latest = appointment_data.dig(:appointment_details, :is_latest)
        @last_retrieved = appointment_data.dig(:appointment_details, :last_retrieved)
        @contact = appointment_data[:contact]
        @referral_id = referral_details[:referral_number]
        @referral = { referral_number: referral_details[:referral_number]&.to_s }
        @provider_service_id = appointment_data[:provider_service_id]
        @provider_name = appointment_data.dig(:provider, :name).presence || 'unknown'

        @type_of_care = referral&.category_of_care
        @provider_phone = referral&.treating_facility_phone
        @referring_facility_details = parse_referring_facility_details(referral)
        @provider = provider
      end

      def serializable_hash
        {
          id: @id,
          status: determine_status(@status),
          patient_icn: @patient_icn,
          created: @created,
          location_id: @location_id,
          clinic: @clinic,
          start: @start,
          contact: @contact,
          referral_id: @referral_id,
          referral: @referral,
          provider_service_id: @provider_service_id,
          provider_name: @provider_name
        }.compact
      end

      def provider_details
        return nil if provider.nil?

        {
          id: provider.id,
          name: provider.name,
          is_active: provider.is_active,
          organization: provider.provider_organization,
          location: provider.location,
          network_ids: provider.network_ids,
          phone_number: provider_phone
        }.compact
      end

      def parse_referring_facility_details(referral)
        return {} if referral.nil?

        {
          name: referral.referring_facility_name,
          phone_number: referral.referring_facility_phone
        }.compact
      end

      private

      def determine_status(status)
        status == 'booked' ? 'booked' : 'proposed'
      end
    end
  end
end
