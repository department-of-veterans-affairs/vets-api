# frozen_string_literal: true

module IHub
  module Models
    class Appointment < Base
      attribute :date_time, String
      attribute :date_time_date, String
      attribute :assigning_facility, String
      attribute :clinic_code, String
      attribute :clinic_name, String
      attribute :facility_code, String
      attribute :facility_name, String
      attribute :other_information, String
      attribute :status_code, String
      attribute :status_name, String
      attribute :type_code, String
      attribute :type_name, String
      attribute :appointment_status_code, String
      attribute :appointment_status_name, String
      attribute :local_id, String

      def self.build(appointment)
        IHub::Models::Appointment.new(
          date_time: appointment['date_time'],
          date_time_date: appointment['date_time_date'],
          assigning_facility: appointment['assigning_facility'],
          clinic_code: appointment['clinic_code'],
          clinic_name: appointment['clinic_name'],
          facility_code: appointment['facility_code'],
          facility_name: appointment['facility_name'],
          other_information: appointment['other_information'],
          status_code: appointment['status_code'],
          status_name: appointment['status_name'],
          type_code: appointment['type_code'],
          type_name: appointment['type_name'],
          appointment_status_code: appointment['appointment_status_code'],
          appointment_status_name: appointment['appointment_status_name'],
          local_id: appointment['local_id']
        )
      end

      def self.convert(appointments)
        appointments.map { |appointment| build(appointment) }
      end
    end
  end
end
