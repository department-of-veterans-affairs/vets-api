# frozen_string_literal: true

require 'common/models/base'
require_relative 'pciu_address_line_validator'

module EVSS
  module PCIUAddress
    class Address
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      ADDRESS_TYPES = {
        domestic: 'DOMESTIC',
        international: 'INTERNATIONAL',
        military: 'MILITARY'
      }.freeze
      ZIP_CODE_REGEX = /\A\d{5}\z/
      ZIP_SUFFIX_REGEX = /\A-?\d{4}\z/

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String

      validates :address_one, pciu_address_line: true, presence: true, length: { maximum: 35 }
      validates :address_two, pciu_address_line: true, length: { maximum: 35 }
      validates :address_three, pciu_address_line: true, length: { maximum: 35 }
      validates :type, inclusion: { in: ADDRESS_TYPES.values }

      def self.build_address(attrs)
        case attrs['type']
        when ADDRESS_TYPES[:domestic]
          EVSS::PCIUAddress::DomesticAddress.new(attrs)
        when ADDRESS_TYPES[:international]
          EVSS::PCIUAddress::InternationalAddress.new(attrs)
        when ADDRESS_TYPES[:military]
          EVSS::PCIUAddress::MilitaryAddress.new(attrs)
        else
          raise ArgumentError, "Unsupported address type: #{attrs['type']}"
        end
      end
    end
  end
end
