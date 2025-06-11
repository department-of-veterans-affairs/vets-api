# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointment
      attr_reader :id, :status, :patient_icn, :created, :location_id, :clinic,
                  :start, :is_latest, :last_retrieved, :contact, :referral_id,
                  :referral, :provider_service_id, :provider_name,
                  :provider

      def initialize(appointment_data = {}, provider = nil)
        appointment_details = appointment_data[:appointment_details]
        referral_details = appointment_data[:referral]

        @id = appointment_data[:id]&.to_s
        @status = determine_status(appointment_details&.dig(:status))
        @patient_icn = appointment_data[:patient_id]
        @created = appointment_details&.dig(:last_retrieved)
        @location_id = appointment_data[:network_id]
        @clinic = appointment_data[:provider_service_id]
        @start = appointment_details&.dig(:start)
        @is_latest = appointment_details&.dig(:is_latest)
        @last_retrieved = appointment_details&.dig(:last_retrieved)
        @contact = appointment_data[:contact]
        @referral_id = referral_details&.dig(:referral_number)
        @referral = { referral_number: referral_details&.dig(:referral_number)&.to_s }
        @provider_service_id = appointment_data[:provider_service_id]
        @provider_name = appointment_data.dig(:provider, :name).presence || 'unknown'
        @provider = provider
      end

      def serializable_hash
        {
          id: @id,
          status: @status,
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

        result = {
          id: provider.id,
          name: provider.provider_name,
          practice: provider.practice_name,
          location: provider.location
        }

        # Transform address fields if address exists
        if provider.address.present?
          result[:address] = {
            street1: provider.address[:line1],
            street2: provider.address[:line2],
            city: provider.address[:city],
            state: provider.address[:state],
            zip: provider.address[:postal_code]
          }.compact
        end

        result.compact
      end

      private

      def determine_status(status)
        status == 'booked' ? 'booked' : 'proposed'
      end
    end
  end
end
