# frozen_string_literal: true

require 'common/models/base'
require_relative 'pciu_address_line_validator'

module EVSS
  module PCIUAddress
    ##
    # Model for PCIU address
    #
    # @!attribute type
    #   @return [String] Address type; one of %w[DOMESTIC INTERNATIONAL MILITARY]
    # @!attribute address_effective_date
    #   @return [DateTime] The date at which the address is known to be valid
    # @!attribute address_one
    #   @return [String] The first line of the address (max 35 characters)
    # @!attribute address_two
    #   @return [String] The second line of the address (max 35 characters)
    # @!attribute address_three
    #   @return [String] The third line of the address (max 35 characters)
    #
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
    end
  end
end
