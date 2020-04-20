# frozen_string_literal: true

module MDOT
  class Address
    include Virtus.model

    attribute :street, String
    attribute :street2, String
    attribute :city, String
    attribute :state, String
    attribute :country, String
    attribute :postal_code, String
    attribute :is_military_base, Boolean, default: false
  end
end
