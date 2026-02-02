# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      module Concerns
        module GathererUtilities
          extend ActiveSupport::Concern
          NULL_PHONE_DATA = [nil, nil, nil].freeze

          def parse_phone_number(number)
            return NULL_PHONE_DATA unless number_is_parsable?(number)

            if number.length == 10
              area_code = number[0, 3]
              phone_number = number[-7, 7]
              country_code = nil
            elsif number.length == 11
              area_code = number[1, 3]
              phone_number = number[-7, 7]
              country_code = number[0, 1]
            else
              return NULL_PHONE_DATA
            end

            [country_code, area_code, phone_number]
          end

          def number_is_parsable?(number)
            number.present? && number.is_a?(String) && number.length < 12
          end
        end
      end
    end
  end
end
