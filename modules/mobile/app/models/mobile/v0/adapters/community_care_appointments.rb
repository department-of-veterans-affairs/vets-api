# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      # This class adapts Community Care appointments to a common schema that
      # is shared with the VA appointment types.
      #
      # @example create a new instance and parse incoming data
      #   Mobile::V0::Adapters::CommunityCareAppointments.new.parse(appointments)
      #
      class CommunityCareAppointments
        BOOKED_STATUS = 'BOOKED'
        COMMUNITY_CARE_TYPE = 'COMMUNITY_CARE'

        # Takes a result set of Community Care appointments from the appointments web
        # service and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of various Community Care appointment types
        #
        # @return Array<Mobile::V0::Appointment> the adapted list of appointment models
        #
        def parse(appointments)
          appointments_list = appointments[:booked_appointment_collections].first[:booked_cc_appointments]

          appointments_list.map do |appointment_hash|
            location = get_location(appointment_hash[:provider_practice], appointment_hash[:address])

            adapted_hash = {
              appointment_type: COMMUNITY_CARE_TYPE,
              comment: appointment_hash[:instructions_to_veteran],
              facility_id: nil, # not a VA location
              healthcare_service: appointment_hash[:provider_practice],
              location: location,
              minutes_duration: 60, # not in raw data, matches va.gov default for cc appointments
              start_date: get_start_date(appointment_hash[:appointment_time], appointment_hash[:time_zone]),
              status: BOOKED_STATUS,
              time_zone: get_time_zone_region(appointment_hash[:time_zone], location.dig(:address, :state))
            }

            Mobile::V0::Appointment.new(adapted_hash)
          end
        end

        private

        def get_location(name, address)
          {
            name: name,
            address: {
              street: address[:street],
              city: address[:city],
              state: address[:state],
              zip_code: address[:zip_code]
            },
            phone: {
              area_code: nil,
              number: nil,
              extension: nil
            },
            url: nil,
            code: nil
          }
        end

        def get_start_date(appointment_time, time_zone)
          time_zone_split = time_zone.split
          offset = time_zone_split.size > 1 ? time_zone_split[0] : '+00:00'
          DateTime.strptime(appointment_time + offset, '%m/%d/%Y %H:%M:%S%z')
        end

        def get_time_zone_region(time_zone, state)
          offset, time_zone = time_zone.split
          return nil if offset == 'UTC'
          # Arizona does not observe daylight savings time.
          # The Navajo Nation does observe daylight savings time but veteran care
          # is provided at the Navajo Nation VA or at US Government VA clinics (non Nation zip codes)
          return 'America/Phoenix' if state == 'AZ'

          Mobile::VA_TZ_DATABASE_NAMES_BY_SCHEDULE[time_zone]
        end
      end
    end
  end
end
