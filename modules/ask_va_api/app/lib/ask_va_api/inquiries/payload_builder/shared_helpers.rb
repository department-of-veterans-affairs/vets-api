# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      module SharedHelpers
        # interim mapping for labels missing from locations.yml
        # TODO: remove once frontend begins sending state codes (see AskVA #1825)
        MISSING_STATE_CODES = {
          'American Samoa' => 'AS',
          'Armed Forces Americas (AA)' => 'AA',
          'Armed Forces Europe (AE)' => 'AE',
          'Armed Forces Pacific (AP)' => 'AP',
          'Federated States Of Micronesia' => 'FM',
          'Marshall Islands' => 'MH',
          'Northern Mariana Islands' => 'MP'
        }.freeze

        def fetch_country(country_code)
          return if country_code.blank?

          country_code = 'US' if country_code == 'USA'
          I18n.t("ask_va_api.countries.#{country_code}", default: country_code)
        end

        def fetch_state(state_code)
          return if state_code.blank?

          I18n.t("ask_va_api.states.#{state_code}", default: state_code)
        end

        def formatted_pronouns(pronouns)
          return unless pronouns

          pronouns[:pronouns_not_listed_text].presence || pronouns.key('true')&.to_s&.tr('_', '/')
        end

        def fetch_state_code(state)
          return if state.blank?

          state = state.to_s.strip

          # pass through once frontend begins sending two-letter state codes
          return state.upcase if state.length == 2

          return MISSING_STATE_CODES[state] if MISSING_STATE_CODES[state]

          # otherwise continue with existing behavior
          I18n.t('ask_va_api.states').invert[state]&.to_s
        end

        def contact_info
          @contact_info ||= {
            BusinessPhone: retrieve_contact_field(:phone_number, 'Business'),
            PersonalPhone: retrieve_contact_field(:phone_number, 'Personal'),
            BusinessEmail: retrieve_contact_field(:email_address, 'Business'),
            PersonalEmail: retrieve_contact_field(:email_address, 'Personal')
          }
        end

        def school_info
          {
            SchoolState: inquiry_params.dig(:school_obj, :state_abbreviation),
            SchoolFacilityCode: inquiry_params.dig(:school_obj, :school_facility_code),
            SchoolId: nil
          }
        end

        def retrieve_contact_field(field, required_authentication_level)
          inquiry_details[:level_of_authentication] == required_authentication_level ? inquiry_params[field] : nil
        end
      end
    end
  end
end
