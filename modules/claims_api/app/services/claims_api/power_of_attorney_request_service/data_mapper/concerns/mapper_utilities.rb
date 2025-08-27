# frozen_string_literal: true

require 'brd/brd'

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

          # rubocop:disable Metrics/MethodLength
          def build_claimant_form_data(data)
            {
              'claimant' => {
                'claimantId' => data['claimant']['claimant_id'],
                'address' => {
                  'addressLine1' => data['claimant']['addrs_one_txt'],
                  'addressLine2' => data['claimant']['addrs_two_txt'],
                  'city' => data['claimant']['city_nm'],
                  'stateCode' => data['claimant']['postal_cd'],
                  'countryCode' => ClaimsApi::BRD::COUNTRY_CODES.invert[data['claimant']['cntry_nm']],
                  'zipCode' => data['claimant']['zip_prefix_nbr'],
                  'zipCodeSuffix' => data['claimant']['zip_first_suffix_nbr']
                },
                'phone' => {
                  'countryCode' => parse_phone_number(data['claimant']['phone_nbr'])[0],
                  'areaCode' => parse_phone_number(data['claimant']['phone_nbr'])[1],
                  'phoneNumber' => parse_phone_number(data['claimant']['phone_nbr'])[2]
                },
                'email' => data['claimant']['email_addrs_txt'],
                'relationship' => data['claimant_relationship']
              }
            }
          end
          # rubocop:enable Metrics/MethodLength

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

          def determine_consent_limits(data)
            keys = CONSENT_LIMITS.keys
            limits = []
            keys.each do |key|
              value = data[key]
              limits << CONSENT_LIMITS[key] if value == 'true'
            end

            limits
          end

          def deep_compact(obj)
            case obj
            when Hash
              obj.each_with_object({}) do |(k, v), result|
                nested = deep_compact(v)
                result[k] = nested unless nested.nil? || nested == {}
              end
            when Array
              array = obj.map { |v| deep_compact(v) }.reject { |v| v.nil? || v == {} }
              array.empty? ? nil : array
            else
              obj.nil? ? nil : obj
            end
          end
        end
      end
    end
  end
end
