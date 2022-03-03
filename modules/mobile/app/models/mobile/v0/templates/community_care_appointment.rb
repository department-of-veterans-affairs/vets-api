# frozen_string_literal: true

module Mobile
  module V0
    module Templates
      class CommunityCareAppointment < BaseAppointment
        def appointment_type
          # if cc video conferences are possible, they will need a new appointment type
          unless @request[:visit_type].in?(['Office Visit', 'Phone Call'])
            Rails.logger.error(
              'Unknown appointment request type',
              { appointment_type: 'COMMUNITY_CARE', visit_type: @request[:visit_type] }
            )
          end
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
            phone: phone_captures,
            url: nil,
            code: nil
          }
        end

        def phone_captures
          phone_components = { area_code: nil, number: nil, extension: nil }
          return phone_components unless @request[:phone_number]

          # captures area code \((\d{3})\) number (after space) \s(\d{3}-\d{4})
          # and extension (until the end of the string) (\S*)\z
          matches = @request[:phone_number].match(/\((\d{3})\)\s(\d{3}-\d{4})(\S*)\z/)
          return phone_components unless matches

          phone_components[:area_code] = matches[1].presence
          phone_components[:number] = matches[2].presence
          phone_components[:extension] = matches[3].presence
          phone_components
        end
      end
    end
  end
end
