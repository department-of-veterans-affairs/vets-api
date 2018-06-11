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

    class StatesResponse < Response
      attribute :states, Array[Hash]

      def self.from(response)
        new(response.status, states: response.body['state_list'])
      end
    end

    class ZipcodesResponse < Response
      attribute :zipcodes, Array[Hash]

      def self.from(response)
        data = response.body['zip_code5_list'].map do |z|
          { 'zip_code' => z['zip_code5'] }
        end

        new(response.status, zipcodes: data)
      end
    end
  end
end
