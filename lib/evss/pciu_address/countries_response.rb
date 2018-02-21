# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIUAddress
    class CountriesResponse < EVSS::Response
      attribute :countries, Array[String]

      def initialize(status, response = nil)
        countries = response&.body&.dig('cnp_countries') || response&.body&.dig('countries')
        super(status, countries: countries)
      end
    end
  end
end
