# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAAppointments
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
        VIDEO_GFE_FLAG = 'MOBILE_GFE'

        def parse(appointments)
          facilities = Set.new

          appointments_list = appointments.dig('data', 'appointmentList')
          appointments_list.map do |appointment_hash|
            facilities.add(appointment_hash['facilityId']) if appointment_hash['facilityId']
            details, type = parse_by_appointment_type(appointment_hash)
            start_date = get_start_date(appointment_hash)

            {
              appointment_type: type,
              comment: comment(details, type),
              facility_id: appointment_hash['facilityId'],
              healthcare_service: healthcare_service(details, type),
              location: nil,
              minutes_duration: minutes_duration(details, type),
              start_date: start_date,
              status: get_status(details, type, start_date),
              time_zone: nil
            }
          end
        end

        private

        def get_status(details, type, start_date)
          status = va?(type) ? details['currentStatus'] : details.dig('status', 'code')
          return nil if should_hide_status?(start_date.past?, status)
          return Mobile::V0::Appointment::STATUSES['CANCELLED'] if CANCELLED_STATUS.include?(status)

          Mobile::V0::Appointment::STATUSES['BOOKED']
        end

        def should_hide_status?(is_past, status)
          is_past && PAST_HIDDEN_STATUS.include?(status) || !is_past && FUTURE_HIDDEN_STATUS.include?(status)
        end

        def get_start_date(appointment_hash)
          Date.parse(appointment_hash['startDate'])
        end

        def parse_by_appointment_type(appointment)
          if on_site?(appointment)
            return [appointment['vdsAppointments']&.first, Mobile::V0::Appointment::APPOINTMENT_TYPES['VA']]
          end

          [appointment['vvsAppointments']&.first, get_video_type(appointment)]
        end

        def get_video_type(appointment)
          return Mobile::V0::Appointment::APPOINTMENT_TYPES['VA_VIDEO_CONNECT_ATLAS'] if video_atlas?(appointment)
          return Mobile::V0::Appointment::APPOINTMENT_TYPES['VA_VIDEO_CONNECT_GFE'] if video_gfe?(appointment)

          Mobile::V0::Appointment::APPOINTMENT_TYPES['VA_VIDEO_CONNECT_HOME']
        end

        def video_atlas?(appointment)
          return false unless appointment['vvsAppointments']

          appointment['vvsAppointments'].first['tasInfo'].present?
        end

        def video_gfe?(appointment)
          return false unless appointment['vvsAppointments']

          appointment['vvsAppointments'].first['appointmentKind'] == VIDEO_GFE_FLAG
        end

        def comment(details, type)
          va?(type) ? details['bookingNote'] : details['instructionsTitle']
        end

        def on_site?(appointment)
          appointment['vdsAppointments']&.size&.positive?
        end

        def va?(type)
          type == Mobile::V0::Appointment::APPOINTMENT_TYPES['VA']
        end

        def healthcare_service(details, type)
          va?(type) ? details.dig('clinic', 'name') : video_healthcare_service(details)
        end

        def video_healthcare_service(details)
          providers = details['providers']
          return nil unless providers

          provider = if providers.is_a?(Array)
                       details.dig('providers')
                     else
                       details.dig('providers', 'provider')
                     end
          return nil unless provider

          provider.first.dig('location', 'facility', 'name')
        end

        def minutes_duration(details, type)
          va?(type) ? details['appointmentLength'] : details['duration']
        end
      end
    end
  end
end
