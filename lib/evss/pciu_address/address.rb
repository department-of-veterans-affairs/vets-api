# frozen_string_literal: true
require 'common/models/base'

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

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String
      attribute :city, String
      attribute :country_name, String

      validates :address_one, presence: true
      validates :type, inclusion: { in: ADDRESS_TYPES }

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
