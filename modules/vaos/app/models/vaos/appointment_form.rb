# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/models/attribute_types/iso8601_time'

module VAOS
  class AppointmentForm < Common::Form
    attribute :appointment_type, String
    attribute :scheduling_request_type, String
    attribute :type, String
    attribute :appointment_kind, String
    attribute :desired_date, String
    attribute :date_time, String
    attribute :duration, Integer
    attribute :booking_notes, String
    attribute :patient_information, Hash
    attribute :appointment_location, Hash

    def initialize(user, json_hash)
      @user = user
      super(json_hash)
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes.compact
               .except(:patient_information, :appointment_location)
               .merge(patients: patients)
    end

    private

    def patients
      {
        patient: [
          id: {
            unique_id: @user.icn,
            assigning_authority: 'ICN'
          },
          name: {
            first_name: @user.first_name,
            last_name: @user.last_name
          },
          contact_information: patient_information,
          location: appointment_location
        ]
      }
    end

    def first_name
      @user.mvi&.profile&.given_names&.first
    end

    def last_name
      @user.mvi&.profile&.family_name
    end
  end
end
