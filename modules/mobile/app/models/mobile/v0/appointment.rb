# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Appointment < Common::Resource
      APPOINTMENT_TYPE = Types::String.enum(
        'COMMUNITY_CARE',
        'VA',
        'VA_VIDEO_CONNECT_ATLAS',
        'VA_VIDEO_CONNECT_GFE',
        'VA_VIDEO_CONNECT_HOME'
      )
      STATUS_TYPE = Types::String.enum('BOOKED', 'CANCELLED')
      TIME_ZONE_TYPE = Types::String.enum(
        'America/Argentina/San_Juan',
        'America/Anchorage',
        'America/Chicago',
        'America/Denver',
        'America/Los_Angeles',
        'America/New_York',
        'America/Phoenix',
        'Asia/Manila',
        'Pacific/Honolulu'
      )

      attribute :appointment_type, APPOINTMENT_TYPE
      attribute :comment, Types::String.optional
      attribute :facility_id, Types::String.optional
      attribute :healthcare_service, Types::String.optional
      attribute :location, AppointmentLocation
      attribute :minutes_duration, Types::Integer
      attribute :start_date, Types::DateTime
      attribute :status, STATUS_TYPE
      attribute :time_zone, TIME_ZONE_TYPE
    end
  end
end
