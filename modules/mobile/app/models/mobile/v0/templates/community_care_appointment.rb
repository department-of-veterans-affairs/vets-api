# frozen_string_literal: true

module Mobile
  module V0
    module Templates
      class CommunityCareAppointment < BaseAppointment
        def appointment_type
          'COMMUNITY_CARE'
        end

        def provider_name
          provider_section = @request.dig(:cc_appointment_request, :preferred_providers, 0)
          return nil if provider_section.nil?

          return nil if provider_section[:first_name].blank? && provider_section[:last_name].blank?

          "#{provider_section[:first_name]} #{provider_section[:last_name]}".strip
        end

        def practice_name
          @request.dig(:cc_appointment_request, :preferred_providers, 0, :practice_name)
        end

        def location
          address = @request.dig(:cc_appointment_request, :preferred_providers, 0, :address) || {}
          {
            id: nil,
            name: practice_name,
            address: {
              street: address[:street],
              city: address[:city],
              state: address[:state],
              zip_code: address[:zip_code]
            },
            lat: nil,
            long: nil,
            phone: nil,
            url: nil,
            code: nil
          }
        end
      end
    end
  end
end
