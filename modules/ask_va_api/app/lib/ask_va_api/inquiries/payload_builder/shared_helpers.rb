# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      module SharedHelpers
        def fetch_country(country_code)
          country_code = 'US' if country_code == 'USA'
          I18n.t("ask_va_api.countries.#{country_code}", default: country_code)
        end

        def fetch_state(state_code)
          I18n.t("ask_va_api.states.#{state_code}", default: state_code)
        end

        def formatted_pronouns(pronouns)
          return pronouns[:pronouns_not_listed_text] unless pronouns[:pronouns_not_listed_text].empty?

          pronouns&.key(true).to_s.tr('_', '/')
        end

        def contact_field(field, inquiry_details, inquiry_params)
          inquiry_details[:level_of_authentication] == 'Business' ? inquiry_params[field] : nil
        end

        def fetch_state_code(state)
          I18n.t('ask_va_api.states').invert[state].to_s
        end
      end
    end
  end
end
