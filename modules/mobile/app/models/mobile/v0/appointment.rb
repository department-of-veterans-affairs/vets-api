# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # Model that can be populated by either Community Care or the four
    # VA appointment types
    #
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::Appointment.new(appointment_hash)
    #
    class Appointment < Common::Resource
      APPOINTMENT_TYPE = Types::String.enum(
        'COMMUNITY_CARE',
        'VA',
        'VA_VIDEO_CONNECT_ATLAS',
        'VA_VIDEO_CONNECT_GFE',
        'VA_VIDEO_CONNECT_HOME'
      )
      STATUS_TYPE = Types::String.enum('BOOKED', 'CANCELLED', 'HIDDEN')
      TIME_ZONE_TYPE = Types::String.enum(
        'America/Argentina/San_Juan',
        'America/Anchorage',
        'America/Chicago',
        'America/Denver',
        'America/Los_Angeles',
        'America/New_York',
        'America/Phoenix',
        'Asia/Manila',
        'Pacific/Honolulu',
        nil
      )

      attribute :id, Types::String
      attribute :appointment_type, APPOINTMENT_TYPE
      attribute :comment, Types::String.optional
      attribute :clinic_id, Types::String.optional
      attribute :facility_id, Types::String.optional
      attribute :healthcare_service, Types::String.optional
      attribute :location, AppointmentLocation
      attribute :minutes_duration, Types::Integer
      attribute :start_date_local, Types::DateTime
      attribute :start_date_utc, Types::DateTime
      attribute :status, STATUS_TYPE
      attribute :time_zone, TIME_ZONE_TYPE
    end
  end
end
