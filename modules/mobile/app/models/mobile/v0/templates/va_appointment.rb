# frozen_string_literal: true

module Mobile
  module V0
    module Templates
      class VAAppointment < BaseAppointment
        def appointment_type
          case @request[:visit_type]
          when 'Video Conference'
            'VA_VIDEO_CONNECT_HOME'
          else
            'VA'
          end
        end

        def facility_id
          @facility_id ||= Mobile::V0::Appointment.convert_from_non_prod_id!(@request.dig(:facility, :facility_code))
        end

        def location
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          {
            id: facility_id,
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
        end
      end
    end
  end
end
