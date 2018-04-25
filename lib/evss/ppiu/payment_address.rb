# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
    class PaymentAddress
      include Virtus.model

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String
      attribute :city, String
      attribute :state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String
      attribute :country_name, String
      attribute :military_post_office_type_code, String
      attribute :military_state_code, String
    end
  end
end
