# frozen_string_literal: true

module AskVAApi
  module Zipcodes
    class Entity
      attr_reader :id,
                  :zipcode,
                  :city,
                  :state,
                  :lat,
                  :lng

      def initialize(info)
        @id = info[:id]
        @zipcode = info[:zip]
        @city = info[:city]
        @state = info[:state]
        @lat = info[:lat]
        @lng = info[:lng]
      end
    end
  end
end
