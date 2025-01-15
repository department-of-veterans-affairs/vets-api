# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointmentSerializer
      def serialize(appt)
        {
          id: appt[:id].to_s,
          status: appt.dig(:appointment_details, :status) ? 'booked' : 'proposed',
          patient_icn: appt[:patient_id],
          created: appt.dig(:appointment_details, :last_retrieved),
          location_id: appt[:network_id],
          clinic: appt[:provider_service_id],
          start: appt.dig(:appointment_details, :start),
          contact: appt[:contact],
          referral_id: appt.dig(:referral, :referral_number),
          referral: {
            referral_number: appt.dig(:referral, :referral_number).to_s
          }
        }.compact
      end

      private

      def calculate_end_time(start_time)
        return nil unless start_time

        Time.zone.parse(start_time) + 60.minutes
      end
    end
  end
end