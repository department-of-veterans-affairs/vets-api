# frozen_string_literal: true

require 'common/models/resource'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    # Model that can be populated by either Community Care or the four
    # VA appointment types
    #
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::Appointment.new(appointment_hash)
    #
    class Appointment < Common::Resource
      CACHE_VERSION = 1

      include Mobile::V0::Concerns::RedisCaching

      redis_config REDIS_CONFIG[:mobile_app_appointments_store], CACHE_VERSION

      APPOINTMENT_TYPE = Types::String.enum(
        'COMMUNITY_CARE',
        'VA',
        'VA_VIDEO_CONNECT_ATLAS',
        'VA_VIDEO_CONNECT_GFE',
        'VA_VIDEO_CONNECT_HOME',
        'VA_VIDEO_CONNECT_ONSITE'
      )
      STATUS_TYPE = Types::String.enum('BOOKED', 'CANCELLED', 'HIDDEN', 'SUBMITTED')
      STATUS_DETAIL_TYPE = Types::String.enum('CANCELLED BY CLINIC & AUTO RE-BOOK',
                                              'CANCELLED BY CLINIC',
                                              'CANCELLED BY PATIENT & AUTO-REBOOK',
                                              'CANCELLED BY PATIENT',
                                              'CANCELLED - OTHER')
      TIME_ZONE_TYPE = Types::String.enum(
        'America/Argentina/San_Juan',
        'America/Puerto_Rico',
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
      attribute :sta6aid, Types::String.optional
      attribute :healthcare_provider, Types::String.optional
      attribute :healthcare_service, Types::String.optional
      attribute :location, Location.optional
      attribute :minutes_duration, Types::Integer
      attribute :phone_only, Types::Bool
      attribute :start_date_local, Types::DateTime
      attribute :start_date_utc, Types::DateTime
      attribute :status, STATUS_TYPE
      attribute :status_detail, STATUS_DETAIL_TYPE.optional
      attribute :time_zone, TIME_ZONE_TYPE
      attribute :vetext_id, Types::String.optional
      attribute :reason, Types::String.optional
      attribute :is_covid_vaccine, Types::Bool
      attribute :is_pending, Types::Bool
      attribute :proposed_times, Types::Array.optional
      attribute :type_of_care, Types::String.optional
      attribute :patient_phone_number, Types::String.optional
      attribute :patient_email, Types::String.optional
      attribute :best_time_to_call, Types::Array.optional
      attribute :friendly_location_name, Types::String.optional
      attribute :service_category_name, Types::String.optional

      # On staging, some upstream services use different facility ids for the same facility.
      # These methods convert between the two sets of ids.
      # 983 == 442 and 984 == 552
      # For example, Lighthouse only recognizes 442 but not 983 while the
      # VAOS cancel service only recognizes 983 but not 442
      def self.convert_from_non_prod_id!(id)
        return id if Settings.hostname == 'api.va.gov' || id.nil?

        match = id.match(/\A(983|984)/)
        return id unless match

        return id.sub(match[0], '442') if match[0] == '983'

        id.sub(match[0], '552') if match[0] == '984'
      end

      def self.convert_to_non_prod_id!(id)
        return id if Settings.hostname == 'api.va.gov' || id.nil?

        match = id.match(/\A(442|552)/)
        return id unless match

        return id.sub(match[0], '983') if match[0] == '442'

        id.sub(match[0], '984') if match[0] == '552'
      end
    end
  end
end
