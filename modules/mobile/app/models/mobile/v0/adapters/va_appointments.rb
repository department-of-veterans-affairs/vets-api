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
      class VAAppointments
        APPOINTMENT_TYPES = {
          va: 'VA',
          va_video_connect_atlas: 'VA_VIDEO_CONNECT_ATLAS',
          va_video_connect_gfe: 'VA_VIDEO_CONNECT_GFE',
          va_video_connect_home: 'VA_VIDEO_CONNECT_HOME'
        }.freeze

        CANCELLED_STATUS = [
          'CANCELLED BY CLINIC & AUTO RE-BOOK',
          'CANCELLED BY CLINIC',
          'CANCELLED BY PATIENT & AUTO-REBOOK',
          'CANCELLED BY PATIENT'
        ].freeze

        FUTURE_HIDDEN = %w[NO-SHOW DELETED].freeze

        FUTURE_HIDDEN_STATUS = [
          'ACT REQ/CHECKED IN',
          'ACT REQ/CHECKED OUT'
        ].freeze

        PAST_HIDDEN = %w[FUTURE DELETED null <null> Deleted].freeze

        PAST_HIDDEN_STATUS = [
          'ACTION REQUIRED',
          'INPATIENT APPOINTMENT',
          'INPATIENT/ACT REQ',
          'INPATIENT/CHECKED IN',
          'INPATIENT/CHECKED OUT',
          'INPATIENT/FUTURE',
          'INPATIENT/NO ACT TAKN',
          'NO ACTION TAKEN',
          'NO-SHOW & AUTO RE-BOOK',
          'NO-SHOW',
          'NON-COUNT'
        ].freeze

        STATUSES = {
          booked: 'BOOKED',
          cancelled: 'CANCELLED'
        }.freeze

        VIDEO_GFE_FLAG = 'MOBILE_GFE'

        # Takes a result set of VA appointments from the appointments web service
        # and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of various VA appointment types
        #
        # @return Hash the adapted list
        #
        def parse(appointments)
          facilities = Set.new

          appointments_list = appointments.dig(:data, :appointment_list)
          appointments = appointments_list.map do |appointment_hash|
            build_appointment_model(appointment_hash, facilities)
          end

          [appointments, facilities]
        end

        private

        def build_appointment_model(appointment_hash, facilities)
          facility_id = sub_non_prod_id!(appointment_hash[:facility_id])
          facilities.add(facility_id) if facility_id
          details, type = parse_by_appointment_type(appointment_hash)
          start_date_utc = start_date_utc(appointment_hash)
          time_zone = time_zone(facility_id)

          adapted_hash = {
            id: SecureRandom.uuid,
            appointment_type: type,
            comment: comment(details, type),
            facility_id: facility_id,
            healthcare_service: healthcare_service(details, type),
            location: location(details, type, facility_id),
            minutes_duration: minutes_duration(details, type),
            start_date_local: start_date_utc.in_time_zone(time_zone),
            start_date_utc: start_date_utc,
            status: status(details, type, start_date_utc)
          }

          Mobile::V0::Appointment.new(adapted_hash)
        end

        def sub_non_prod_id!(id)
          return id if Settings.hostname == 'www.va.gov'

          id.sub!('983', '442') if id.start_with?('983')
          id.sub!('984', '552') if id.start_with?('984')
          id
        end

        def comment(details, type)
          va?(type) ? details[:booking_note] : details[:instructions_title]
        end

        def status(details, type, start_date)
          status = va?(type) ? details[:current_status] : details.dig(:status, :code)
          return nil if should_hide_status?(start_date.past?, status)
          return STATUSES[:cancelled] if CANCELLED_STATUS.include?(status)

          STATUSES[:booked]
        end

        def start_date_utc(appointment_hash)
          DateTime.parse(appointment_hash[:start_date])
        end

        def location(details, type, facility_id)
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          location = {
            name: facility ? facility[:name] : nil,
            address: {
              street: nil,
              city: nil,
              state: nil,
              zip_code: nil
            },
            lat: nil,
            long: nil,
            phone: {
              area_code: nil,
              number: nil,
              extension: nil
            },
            url: nil,
            code: nil
          }

          location_by_type(details, location, type)
        end

        def location_by_type(details, location, type)
          case type
          when APPOINTMENT_TYPES[:va_video_connect_home]
            location_home(details, location)
          when APPOINTMENT_TYPES[:va_video_connect_atlas]
            location_atlas(details, location)
          when APPOINTMENT_TYPES[:va_video_connect_gfe]
            location_gfe(details, location)
          else
            location
          end
        end

        def time_zone(facility_id)
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          facility ? facility[:time_zone] : nil
        end

        def video_type(appointment)
          return APPOINTMENT_TYPES[:va_video_connect_atlas] if video_atlas?(appointment)
          return APPOINTMENT_TYPES[:va_video_connect_gfe] if video_gfe?(appointment)

          APPOINTMENT_TYPES[:va_video_connect_home]
        end

        def healthcare_service(details, type)
          va?(type) ? details.dig(:clinic, :name) : video_healthcare_service(details)
        end

        def location_home(details, location)
          provider = details.dig(:providers, :provider)
          location[:url] = provider.first.dig(:virtual_meeting_room, :url)
          location[:code] = provider.first.dig(:virtual_meeting_room, :pin)
          location
        end

        def location_atlas(details, location)
          address = details.dig(:tas_info, :address)
          location[:address] = {
            street: address[:street_address],
            city: address[:city],
            state: address[:state],
            zip_code: address[:zip_code],
            country: address[:country]
          }
          location[:code] = details.dig(:tas_info, :confirmation_code)
          location
        end

        def location_gfe(details, location)
          meeting_room = details[:providers].first[:virtual_meeting_room]
          location[:url] = meeting_room[:url]
          location[:code] = meeting_room[:pin]
          location
        end

        def minutes_duration(details, type)
          minutes_string = va?(type) ? details[:appointment_length] : details[:duration]
          minutes_string&.to_i
        end

        def on_site?(appointment)
          appointment[:vds_appointments]&.size&.positive?
        end

        def parse_by_appointment_type(appointment)
          return [appointment[:vds_appointments]&.first, APPOINTMENT_TYPES[:va]] if on_site?(appointment)

          [appointment[:vvs_appointments]&.first, video_type(appointment)]
        end

        def should_hide_status?(is_past, status)
          is_past && PAST_HIDDEN_STATUS.include?(status) || !is_past && FUTURE_HIDDEN_STATUS.include?(status)
        end

        def va?(type)
          type == APPOINTMENT_TYPES[:va]
        end

        def video_atlas?(appointment)
          return false unless appointment[:vvs_appointments]

          appointment[:vvs_appointments].first[:tas_info].present?
        end

        def video_gfe?(appointment)
          return false unless appointment[:vvs_appointments]

          appointment[:vvs_appointments].first[:appointment_kind] == VIDEO_GFE_FLAG
        end

        def video_healthcare_service(details)
          providers = details[:providers]
          return nil unless providers

          provider = if providers.is_a?(Array)
                       details[:providers]
                     else
                       details.dig(:providers, :provider)
                     end
          return nil unless provider

          provider.first.dig(:location, :facility, :name)
        end
      end
    end
  end
end
