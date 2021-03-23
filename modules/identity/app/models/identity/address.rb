# frozen_string_literal: true

module Identity
  class Address
    attr_accessor :address_1, :address_2, :city, :state, :postal_code, :kind

    def initialize(attrs={})
      @address_1   = attrs[:address_1]
      @address_2   = attrs[:address_2]
      @city        = attrs[:city]
      @state       = attrs[:state]
      @postal_code = attrs[:postal_code]
      @kind        = attrs[:kind]
    end

  end
end