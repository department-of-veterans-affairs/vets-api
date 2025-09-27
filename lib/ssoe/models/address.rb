# frozen_string_literal: true

module SSOe
  module Models
    class Address
      attr_reader :street1, :city, :state, :zipcode

      def initialize(street1:, city:, state:, zipcode:)
        @street1 = street1
        @city = city
        @state = state
        @zipcode = zipcode
      end
    end
  end
end
