# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class AppointmentForm < Common::Form
    attribute :appointment_type, String
    attribute :scheduling_request_type, String
    attribute :type, String
    attribute :appointment_kind, String
    attribute :desired_date, VAOS::AppointmentTime
    attribute :date_time, VAOS::AppointmentTime
    attribute :duration, Integer
    attribute :booking_notes, String
    attribute :preferred_email, String
    attribute :time_zone, String
    attribute :location, Hash

    def initialize(user, json_hash)
      @user = user
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attribute.compact
               .except(:preferred_email, :time_zone, :location)
               .merge(patients: patient)
    end

    def test_data
      {
        appointment_type: 'Primary Care',
        scheduling_request_type: 'NEXT_AVAILABLE_APPT',
        type: 'REGULAR',
        appointment_kind: 'TRADITIONAL',
        desired_date: '11/22/2019 09:30:00',
        date_time: '11/22/2019 09:30:00',
        duration: 20,
        booking_notes: 'tummy hurts',
        patients:       {
          patient: [
            id: {
              unique_id: @user.icn,
              assigning_authority: 'ICN'
            },
            name: {
              first_name: first_name,
              last_name: last_name
            },
            contact_information: {
              preferred_email: 'abraham.lincoln@va.gov',
              time_zone: 'America/Denver'
            },
            location: {
              type: 'VA',
              facility: {
                name: 'CHYSHR-Cheyenne VA Medical Center',
                siteCode: '983',
                time_zone: 'America/Denver'
              },
              clinic: {
                ien: '308',
                name: 'CHY PC KILPATRICK'
              }
            }
          ]
        }
      }
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
            first_name: user.first_name,
            last_name: user.last_name
          },
          contact_information: {
            preferred_email: preferred_email,
            time_zone: time_zone
          },
          location: location
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
