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
      include Mobile::V0::Concerns::RedisCaching

      redis_config REDIS_CONFIG[:mobile_app_appointments_store]

      APPOINTMENT_TYPE = Types::String.enum(
        'COMMUNITY_CARE',
        'VA',
        'VA_VIDEO_CONNECT_ATLAS',
        'VA_VIDEO_CONNECT_GFE',
        'VA_VIDEO_CONNECT_HOME'
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
        return id.sub(match[0], '552') if match[0] == '984'
      end

      def self.convert_to_non_prod_id!(id)
        return id if Settings.hostname == 'api.va.gov' || id.nil?

        match = id.match(/\A(442|552)/)
        return id unless match

        return id.sub(match[0], '983') if match[0] == '442'
        return id.sub(match[0], '984') if match[0] == '552'
      end

      # VAOS appointments aren't cancelled by id but instead by a combination
      # of clinic_id, facility_id, time, and service. The first half of the
      # encoded string matches VEText cancel ids.
      #
      # @start_date_local DateTime the times of the appointment
      # @clinic_id String the id of the clinic within the facility the appointment is scheduled at
      # @facility_id the id of the facility the appointment is scheduled at
      # @healthcare_service String the name of the service within the clinic
      #
      # @return String the combined cancel id
      #
      def self.encode_cancel_id(start_date_local:, clinic_id:, facility_id:, healthcare_service:)
        string = "#{clinic_id};#{start_date_local.strftime('%Y%m%d.%H%S%M')};#{facility_id};#{healthcare_service}"
        Base64.encode64(string)
      end

      # Takes an encoded cancel id and decodes it into a hash of params
      # that can be used to perform the cancellation
      #
      # @cancel_id String the encoded cancel params
      #
      # @return Hash the decoded params
      #
      def self.decode_cancel_id(cancel_id)
        decoded = Base64.decode64(cancel_id)
        clinic_id, start_date_local, facility_id, healthcare_service = decoded.split(';')

        {
          appointmentTime: DateTime.strptime(start_date_local, '%Y%m%d.%H%S%M'),
          clinicId: clinic_id,
          facilityId: facility_id,
          healthcareService: healthcare_service
        }
      rescue ArgumentError, TypeError
        raise Mobile::V0::Exceptions::ValidationErrors, OpenStruct.new(
          { errors: { cancelId: 'invalid cancel id' } }
        )
      end

      def id_for_address
        sta6aid || facility_id
      end
    end
  end
end
