# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      # VA Appointments come in various shapes and sizes. This class adapts
      # VA on-site, video connect, video connect atlas, and video connect with
      # a GFE to a common schema.
      #
      # @example create a new instance and parse incoming data
      #   Mobile::V0::Adapters::VAAppointments.new.parse(appointments)
      #
      class CommunityCareAppointments
        BOOKED_STATUS = 'BOOKED'
        COMMUNITY_CARE_TYPE = 'COMMUNITY_CARE'

        TIME_ZONE_MAP = {
          'AKST' => 'America/Anchorage',
          'AKDT' => 'America/Anchorage',
          'AST' => 'America/Argentina/San_Juan',
          'CDT' => 'America/Chicago',
          'CST' => 'America/Chicago',
          'EDT' => 'America/New_York',
          'EST' => 'America/New_York',
          'HST' => 'America/Honolulu',
          'MDT' => 'America/Denver',
          'MST' => 'America/Denver',
          'PHST' => 'Asia/Manila',
          'PDT' => 'America/Los_Angeles',
          'PST' => 'America/Los_Angeles'
        }.freeze

        # Takes a result set of VA appointments from the appointments web service
        # and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of various VA appointment types
        #
        # @return Hash the adapted list
        #
        def parse(appointments)
          appointments_list = appointments['bookedAppointmentCollections'].first['bookedCCAppointments']

          appointments_list.map do |appointment_hash|
            location = get_location(appointment_hash['providerPractice'], appointment_hash['address'])
            {
              appointment_type: COMMUNITY_CARE_TYPE,
              comment: appointment_hash['instructionsToVeteran'],
              facility_id: nil, # not a VA location
              healthcare_service: appointment_hash['providerPractice'],
              location: location,
              minutes_duration: 60, # not in raw data, matches va.gov default for cc appointments
              start_date: get_start_date(appointment_hash['appointmentTime'], appointment_hash['timeZone']),
              status: BOOKED_STATUS,
              time_zone: get_time_zone(appointment_hash['timeZone'], location.dig(:address, :state))
            }
          end
        end

        private

        def get_location(name, address)
          {
            name: name,
            address: {
              line1: address['street'],
              city: address['city'],
              state: address['state'],
              zip_code: address['zipCode']
            }
          }
        end

        def get_status(details, type, start_date)
          status = va?(type) ? details['currentStatus'] : details.dig('status', 'code')
          return nil if should_hide_status?(start_date.past?, status)
          return STATUSES[:cancelled] if CANCELLED_STATUS.include?(status)

          STATUSES[:booked]
        end

        def get_start_date(appointment_time, time_zone)
          time_zone_split = time_zone.split
          offset = time_zone_split.size > 1 ? time_zone_split[0] : '+00:00'
          DateTime.strptime(appointment_time + offset, '%m/%d/%Y %H:%M:%S%z')
        end

        def get_time_zone(time_zone, state)
          # Arizona does not observe daylight savings time.
          # The Navajo Nation does observe daylight savings time but veteran care
          # is provided at the Navajo Nation VA or at US Government VA clinics (non Nation zip codes)
          return 'America/Phoenix' if state == 'AZ'

          TIME_ZONE_MAP[time_zone.split[1]]
        end
      end
    end
  end
end
