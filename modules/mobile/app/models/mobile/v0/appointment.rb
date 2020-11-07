# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Appointment < Common::Resource
      APPOINTMENT_TYPES = Types::String.enum(
        'COMMUNITY_CARE',
        'VA',
        'VA_VIDEO_CONNECT_ATLAS',
        'VA_VIDEO_CONNECT_GFE',
        'VA_VIDEO_CONNECT_HOME'
      )
      STATUSES = Types::String.enum('BOOKED', 'CANCELLED')
      TIME_ZONES = Types::String.enum(
        'Pacific/Honolulu',
        'America/Anchorage',
        'America/Los_Angeles',
        'America/Phoenix',
        'America/Denver',
        'America/Chicago',
        'America/New_York'
      )

      attribute :appointment_type, Types::String
      attribute :comment, Types::String
      attribute :facility_id, Types::String
      attribute :healthcare_service, Types::String
      attribute :location, Types::String
      attribute :minutes_duration, Types::String
      attribute :start_time, Types::String
      attribute :status, STATUSES
      attribute :time_zone, Types::String
    end
  end
end
