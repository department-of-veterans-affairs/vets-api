# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ReferenceData
    class CountriesResponse < Response
      attribute :countries, Array[Hash]

      def self.from(response)
        data = response.body['country_list'].map do |c|
          {
            'country_name' => c['country_name'],
            'country_code_iso3' => c['country_code_iso3']
          }
        end
        new(response.status, countries: data)
      end
    end
  end
end
