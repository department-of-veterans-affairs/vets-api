# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      module Concerns
        module MapperUtilities
          extend ActiveSupport::Concern

          CONSENT_LIMITS = {
            'limitation_drug_abuse' => 'DRUG_ABUSE',
            'limitation_alcohol' => 'ALCOHOLISM',
            'limitation_hiv' => 'HIV',
            'limitation_sca' => 'SICKLE_CELL'
          }.freeze

          def parse_phone_number(number)
            return [] unless number.is_a?(String) && number.length < 12

            if number.length == 10
              area_code = number[0, 3]
              phone_number = number[-7, 7]
              country_code = nil
            elsif number.length == 11
              area_code = number[1, 3]
              phone_number = number[-7, 7]
              country_code = number[0, 1]
            end

            [country_code, area_code, phone_number]
          end

          def determine_bool_for_form_field(val)
            val == 'true'
          end

          def determine_consent_limits
            keys = CONSENT_LIMITS.keys
            limits = []
            keys.each do |key|
              value = @data[key]
              limits << CONSENT_LIMITS[key] if value == 'true'
            end

            limits
          end
        end
      end
    end
  end
end
