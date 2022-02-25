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
            phone: {
              area_code: phone_captures[1].presence,
              number: phone_captures[2].presence,
              extension: phone_captures[3].presence
            },
            url: nil,
            code: nil
          }
        end

        def phone_captures
          # captures area code \((\d{3})\) number (after space) \s(\d{3}-\d{4})
          # and extension (until the end of the string) (\S*)\z
          @phone_captures ||= @request[:phone_number].match(/\((\d{3})\)\s(\d{3}-\d{4})(\S*)\z/)
        end
      end
    end
  end
end
