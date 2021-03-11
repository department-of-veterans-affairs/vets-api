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
      attribute :cancel_id, Types::String.optional
      attribute :comment, Types::String.optional
      attribute :facility_id, Types::String.optional
      attribute :healthcare_service, Types::String.optional
      attribute :location, AppointmentLocation
      attribute :minutes_duration, Types::Integer
      attribute :start_date_local, Types::DateTime
      attribute :start_date_utc, Types::DateTime
      attribute :status, STATUS_TYPE
      attribute :time_zone, TIME_ZONE_TYPE

      def self.toggle_non_prod_id!(id)
        return id if Settings.hostname == 'www.va.gov'

        match = id.match(/\A(983|984|552|442)/)
        return id unless match

        return id.sub(match[0], (%w[442 983] - [id]).first) if %w[442 983].include? match[0]
        return id.sub(match[0], (%w[552 984] - [id]).first) if %w[552 984].include? match[0]
      end

      def self.get_cached_appointments(user)
        redis = Redis::Namespace.new(REDIS_CONFIG[:mobile_app_appointments_store][:namespace], redis: Redis.current)
        redis.get(user.uuid)
      end

      def self.set_cached_appointments(user, json)
        redis = Redis::Namespace.new(REDIS_CONFIG[:mobile_app_appointments_store][:namespace], redis: Redis.current)
        redis.set(user.uuid, json)
        redis.expire(user.uuid, REDIS_CONFIG[:mobile_app_appointments_store][:each_ttl])
      end

      def self.delete_cached_appointments(user)
        redis = Redis::Namespace.new(REDIS_CONFIG[:mobile_app_appointments_store][:namespace], redis: Redis.current)
        redis.del(user.uuid)
      end
    end
  end
end
