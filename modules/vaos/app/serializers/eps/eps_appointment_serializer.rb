# frozen_string_literal: true

module VAOS
  module Eps
    class EpsAppointmentSerializer
      def initialize(appt)
        @appt = appt
      end

      def serialize
        {
          id: @appt[:id].to_s,
          status: @appt[:state] == 'submitted' ? 'booked' : 'proposed',
          patientIcn: @appt[:patientId],
          created: @appt.dig(:appointmentDetails, :lastRetrieved),
          requestedPeriods: prepare_requested_periods(@appt[:appointmentDetails]),
          locationId: @appt[:locationId],
          clinic: @appt[:clinic],
          contact: @appt[:contact],
          referralID: @appt.dig(:referral, :referralNumber)
        }.compact
      end

      private

      def prepare_requested_periods(details)
        [
          {
            start: details[:start],
            end: calculate_end_time(details[:start])
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