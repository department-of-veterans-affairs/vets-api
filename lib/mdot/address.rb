# frozen_string_literal: true

require 'vets/model'

module MDOT
  class Address
    include Vets::Model

    attribute :street, String
    attribute :street2, String
    attribute :city, String
    attribute :state, String
    attribute :country, String
    attribute :postal_code, String
    attribute :is_military_base, Bool, default: false
  end
end
