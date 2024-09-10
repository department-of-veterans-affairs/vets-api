# frozen_string_literal: true

module ClaimsApi
  module V2
    module LighthouseMilitaryAddressValidator
      MILITARY_CITY_CODES = %w[
        APO
        FPO
        DPO
      ].freeze

      MILITARY_STATE_CODES = %w[
        AE
        AP
      ].freeze

      def address_is_military?(addr)
        return true if MILITARY_CITY_CODES.include?(military_city(addr))
        return true if MILITARY_STATE_CODES.include?(military_state(addr))

        false
      end

      def military_city(addr)
        city = addr['city'] || addr[:city]
        city&.strip&.upcase
      end

      def military_state(addr)
        state = addr['state'] || addr[:state]
        state&.strip&.upcase
      end
    end
  end
end
