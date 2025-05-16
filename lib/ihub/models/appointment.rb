# frozen_string_literal: true

require 'vets/model'

module IHub
  module Models
    class Appointment
      include Vets::Model
      # Potential status_name's
      #
      CHECKED_IN        = 'CHECKED IN'
      CHECKED_OUT       = 'CHECKED OUT'
      NO_ACTION         = 'NO ACTION TAKEN'
      NO_SHOW           = 'NO-SHOW'
      NO_SHOW_RE_BOOK   = 'NO-SHOW & AUTO RE-BOOK'
      INPATIENT         = 'INPATIENT APPOINTMENT'
      FUTURE            = 'FUTURE'
      NON_COUNT         = 'NON-COUNT'
      DELETED           = 'DELETED'
      ACTION_REQUIRED   = 'ACTION REQUIRED'
      CLINIC_CANCELLED  = 'CANCELLED BY CLINIC'
      PATIENT_CANCELLED = 'CANCELLED BY PATIENT'
      CLINIC_CANCELLED_RE_BOOK  = 'CANCELLED BY CLINIC & AUTO RE-BOOK'
      PATIENT_CANCELLED_RE_BOOK = 'CANCELLED BY PATIENT & AUTO-REBOOK'
      STATUS_NAMES = [CHECKED_IN, CHECKED_OUT, NO_ACTION, NO_SHOW, NO_SHOW_RE_BOOK, INPATIENT,
                      FUTURE, NON_COUNT, DELETED, ACTION_REQUIRED, CLINIC_CANCELLED, PATIENT_CANCELLED,
                      CLINIC_CANCELLED_RE_BOOK, PATIENT_CANCELLED_RE_BOOK].freeze

      # Potential type_name's
      #
      COMPENSATION = 'COMPENSATION & PENSION'
      CLASS_II     = 'CLASS II DENTAL'
      ORGAN        = 'ORGAN DONORS'
      EMPLOYEE     = 'EMPLOYEE'
      PRIMA        = 'PRIMA FACIA'
      RESEARCH     = 'RESEARCH'
      COLLATERAL   = 'COLLATERAL OF VET.'
      SHARING      = 'SHARING AGREEMENT'
      REGULAR      = 'REGULAR'
      COMPUTER     = 'COMPUTER GENERATED'
      SERVICE      = 'SERVICE CONNECTED'
      TYPE_NAMES   = [COMPENSATION, CLASS_II, ORGAN, EMPLOYEE, PRIMA, RESEARCH, COLLATERAL,
                      SHARING, REGULAR, COMPUTER, SERVICE].freeze

      # start_time is remapped from iHubs 'date_time_date' attribute
      #
      attribute :start_time, String
      attribute :appointment_status_code, String
      attribute :appointment_status_name, String
      attribute :assigning_facility, String
      attribute :clinic_code, String
      attribute :clinic_name, String
      attribute :facility_code, String
      attribute :facility_name, String
      attribute :local_id, String
      attribute :other_information, String
      attribute :status_code, String
      attribute :status_name, String
      attribute :type_code, String
      attribute :type_name, String

      # Converts an appointment hash from iHub into an instance of the
      # Appointment model class.
      #
      # Important to note that iHub's 'date_time_date' attribute is being
      # remapped to start_time.
      #
      # @param appointment [Hash] A hash of data for one appointment
      # @return [IHub::Models:Appointment] An instance of this class
      #
      def self.build(appointment)
        IHub::Models::Appointment.new(
          appointment_status_code: appointment['appointment_status_code'],
          appointment_status_name: appointment['appointment_status_name'],
          assigning_facility: appointment['assigning_facility'],
          clinic_code: appointment['clinic_code'],
          clinic_name: appointment['clinic_name'],
          facility_code: appointment['facility_code'],
          facility_name: appointment['facility_name'],
          local_id: appointment['local_id'],
          other_information: appointment['other_information'],
          start_time: appointment['date_time_date'],
          status_code: appointment['status_code'],
          status_name: appointment['status_name'],
          type_code: appointment['type_code'],
          type_name: appointment['type_name']
        )
      end

      def self.build_all(appointments)
        appointments.map { |appointment| build(appointment) }
      end
    end
  end
end
