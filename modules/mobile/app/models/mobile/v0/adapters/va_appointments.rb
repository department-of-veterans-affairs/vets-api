# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAAppointments
        VIDEO_GFE_FLAG = 'MOBILE_GFE'

        def parse(appointments)
          facilities = Set.new

          appointments_list = appointments.dig('data', 'appointmentList')
          appointments_list.each do |appointment_hash|
            facilities.add(appointment_hash['facilityId']) if appointment_hash['facilityId']
            details, type = parse_by_appointment_type(appointment_hash)

            attributes = {
              appointment_type: type,
              comment: comment(details, type),
              facility_id: appointment_hash['facilityId'],
              healthcare_service: healthcare_service(details, type),
              location: nil,
              minutes_duration: minutes_duration(details, type)
            }

            # pp appointment_hash
            # puts "-"
            #
            pp attributes
            puts '---'
          end

          puts facilities.to_a.inspect
          appointments_list
        end

        private

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
          video?(type) ? details['instructionsTitle'] : details['bookingNote']
        end

        def on_site?(appointment)
          appointment['vdsAppointments']&.size&.positive?
        end

        def video?(type)
          type != Mobile::V0::Appointment::APPOINTMENT_TYPES['VA']
        end

        def healthcare_service(details, type)
          video?(type) ? video_healthcare_service(details) : details.dig('clinic', 'name')
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
          video?(type) ? details['duration'] : details['appointmentLength']
        end
      end
    end
  end
end
