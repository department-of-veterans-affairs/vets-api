# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointmentSerializer
      def serialize(appt)
        {
          id: appt[:id].to_s,
          status: appt[:state] == 'booked',
          patientIcn: appt[:patientId],
          created: appt.dig(:appointmentDetails, :lastRetrieved),
          requestedPeriods: prepare_requested_periods(appt[:appointmentDetails]),
          locationId: appt[:locationId],
          clinic: appt[:clinic],
          start: appt[:start],
          contact: appt[:contact],
          referralID: appt.dig(:referral, :referralNumber),
          referral: {
            referralNumber: appt.dig(:referral, :referralNumber).to_s
          }
        }.compact
      end

      private

      def prepare_requested_periods(details)
        [
          {
            start: details[:start]
          }
        ].compact
      end

      def calculate_end_time(start_time)
        return nil unless start_time

        Time.zone.parse(start_time) + 60.minutes
      end
    end
  end
end
