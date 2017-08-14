# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module PCIUAddress
    class Address
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String
      attribute :city, String
      attribute :country_name, String
    end
  end
end
