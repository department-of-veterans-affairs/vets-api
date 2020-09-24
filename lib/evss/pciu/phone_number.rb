# frozen_string_literal: true

require 'evss/pciu/base_model'

module EVSS
  module PCIU
    ##
    # Model for PCIU phone numbers
    #
    # @!attribute country_code
    #   @return [String] The country code at the beginning of the phone number
    # @!attribute number
    #   @return [String] The main phone number, digits only
    # @!attribute extension
    #   @return [String] The extension at the end of the phone number
    # @!attribute effective_date
    #   @return [DateTime] Date at which the number was known to be valid
    #
    class PhoneNumber < BaseModel
      attribute :country_code, String
      attribute :number, String
      attribute :extension, String
      attribute :effective_date, DateTime

      validates :number, presence: true
      validates :number, format: { with: /\A\d+\z/, message: 'Only numbers are permitted.' }
    end
  end
end
