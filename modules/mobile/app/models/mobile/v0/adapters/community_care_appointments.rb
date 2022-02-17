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
          appointments_list = appointments.dig(:booked_appointment_collections, 0, :booked_cc_appointments) || []

          appointments_list.map do |appointment_hash|
            location = location(
              appointment_hash[:provider_practice], appointment_hash[:address], appointment_hash[:provider_phone]
            )

            adapted_hash = generate_hash(appointment_hash, location)

            Mobile::V0::Appointment.new(adapted_hash)
          end
        end

        private

        # rubocop:disable Metrics/MethodLength
        def generate_hash(appointment_hash, location)
          start_date_utc = start_date(appointment_hash[:appointment_time], appointment_hash[:time_zone]).utc
          time_zone = time_zone(appointment_hash[:time_zone], location.dig(:address, :state))
          start_date_local = start_date_utc.in_time_zone(time_zone)

          {
            id: appointment_hash[:appointment_request_id],
            appointment_type: COMMUNITY_CARE_TYPE,
            cancel_id: nil,
            comment: appointment_hash[:instructions_to_veteran],
            facility_id: nil,
            sta6aid: nil,
            healthcare_provider: healthcare_provider(appointment_hash[:name]),
            healthcare_service: appointment_hash[:provider_practice],
            location: location,
            minutes_duration: 60, # not in raw data, matches va.gov default for cc appointments
            phone_only: false,
            start_date_local: start_date_local,
            start_date_utc: start_date_utc,
            status: BOOKED_STATUS,
            status_detail: nil, # not currently used by community care appointments
            time_zone: time_zone,
            vetext_id: nil,
            reason: nil,
            is_covid_vaccine: false,
            is_pending: false,
            proposed_times: nil,
            type_of_care: nil,
            patient_phone_number: nil,
            patient_email: nil,
            best_time_to_call: nil,
            friendly_location_name: nil
          }
        end
        # rubocop:enable Metrics/MethodLength

        def healthcare_provider(name_hash)
          return nil if name_hash.nil? || name_hash.values.all?(&:blank?)

          name_hash.values.join(' ').strip
        end

        def location(name, address, phone)
          # captures area code \((\d{3})\) number (after space) \s(\d{3}-\d{4})
          # and extension (until the end of the string) (\S*)\z
          phone_captures = phone.match(/\((\d{3})\)\s(\d{3}-\d{4})(\S*)\z/)
          {
            id: nil,
            name: name,
            address: {
              street: address[:street],
              city: address[:city],
              state: address[:state],
              zip_code: address[:zip_code]
            },
            lat: nil,
            long: nil,
            phone: {
              area_code: phone_captures[1].presence,
              number: phone_captures[2].presence,
              extension: phone_captures[3].presence
            },
            url: nil,
            code: nil
          }
        end

        def start_date(appointment_time, time_zone)
          time_zone_split = time_zone.split
          offset = time_zone_split.size > 1 ? time_zone_split[0] : '+00:00'
          DateTime.strptime(appointment_time + offset, '%m/%d/%Y %H:%M:%S%z')
        end

        def time_zone(time_zone, state)
          # Arizona does not observe daylight savings time.
          # The Navajo Nation does observe daylight savings time but veteran care
          # is provided at the Navajo Nation VA or at US Government VA clinics (non Nation zip codes)
          return 'America/Phoenix' if state == 'AZ'

          Mobile::VA_TZ_DATABASE_NAMES_BY_SCHEDULE[time_zone.split[1]]
        end
      end
    end
  end
end
