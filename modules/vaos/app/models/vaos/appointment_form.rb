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
    attribute :desired_date, Common::ISO8601Time
    attribute :date_time, Common::ISO8601Time
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

    def self.test_data
      data = {
        appointment_type: 'Primary Care',
        scheduling_request_type: 'NEXT_AVAILABLE_APPT',
        type: 'REGULAR',
        appointment_kind: 'TRADITIONAL',
        desired_date: 5.days.from_now.utc.iso8601,
        date_time: 5.days.from_now.utc.iso8601,
        duration: 20,
        booking_notes: 'tummy hurts',
        patient_information: {
          preferred_email: 'abraham.lincoln@va.gov',
          time_zone: 'America/Denver'
        },
        appointment_location: {
          type: 'VA',
          facility: {
            name: 'CHYSHR-Cheyenne VA Medical Center',
            site_code: '983',
            time_zone: 'America/Denver'
          },
          clinic: {
            ien: '308',
            name: 'CHY PC KILPATRICK'
          }
        }
      }

      self.new(FactoryBot.build(:user, :vaos), data)
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
