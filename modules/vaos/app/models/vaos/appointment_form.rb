# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/models/attribute_types/iso8601_time'

module VAOS
  class AppointmentForm < Common::Form
    attribute :scheduling_request_type, String
    attribute :type, String
    attribute :appointment_kind, String
    attribute :scheduling_method, String
    attribute :appt_type, String
    attribute :purpose, String
    attribute :lvl, String
    attribute :ekg, String
    attribute :lab, String
    attribute :x_ray, String
    attribute :desired_date, String
    attribute :date_time, String
    attribute :duration, Integer
    attribute :booking_notes, String
    attribute :preferred_email, String
    attribute :time_zone, String
    attribute :clinic, Hash

    def initialize(user, json_hash)
      @user = user
      super(json_hash)
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes.compact
               .except(:preferred_email, :time_zone)
               .merge(patients: patients, direct: direct, providers: providers)
    end

    private

    def direct
      {
        purpose: booking_notes,
        desired_date: Time.zone.parse(desired_date).strftime('%m/%d/%Y %T'),
        date_time: Time.zone.parse(date_time).strftime('%m/%d/%Y %T'),
        appt_length: duration
      }
    end

    def providers
      {
        provider: [
          {
            location: {
              type: 'VA'
            }
          }
        ]
      }
    end

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
          contact_information: {
            preferred_email: preferred_email,
            time_zone: time_zone
          },
          location: {
            type: 'VA',
            facility: {
              name: clinic[:institution_name],
              site_code: clinic[:site_code],
              time_zone: (clinic[:time_zone] || time_zone),
            },
            clinic: {
              ien: clinic[:clinic_id],
              name: clinic[:clinic_name]
            }
          }
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
