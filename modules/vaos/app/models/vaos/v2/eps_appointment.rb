# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointment
      def initialize(params = {})
        appointment_details = params[:appointment_details]
        referral_details = params[:referral]

        @id = params[:id]&.to_s
        @status = appointment_details[:status]
        @patient_icn = params[:patient_id]
        @created = appointment_details[:last_retrieved]
        @location_id = params[:network_id]
        @clinic = params[:provider_service_id]
        @start = params.dig(:appointment_details, :start)
        @is_latest = params.dig(:appointment_details, :is_latest)
        @last_retrieved = params.dig(:appointment_details, :last_retrieved)
        @contact = params[:contact]
        @referral_id = referral_details[:referral_number]
        @referral = { referral_number: referral_details[:referral_number]&.to_s }
        @provider_service_id = params[:provider_service_id]
        @provider_name = params.dig(:provider, :name).presence || 'unknown'
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
          is_latest: @is_latest,
          last_retrieved: @last_retrieved,
          contact: @contact,
          referral_id: @referral_id,
          referral: @referral,
          provider_service_id: @provider_service_id,
          provider_name: @provider_name
        }.compact
      end

      private

      def determine_status(status)
        status == 'booked' ? 'booked' : 'proposed'
      end
    end
  end
end
