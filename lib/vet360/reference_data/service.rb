# frozen_string_literal: true

require 'common/client/base'
require 'vet360/reference_data/response'

module Vet360
  module ReferenceData
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ReferenceData::Configuration

      def initialize
        super(nil)
      end

      # GETs a the list of valid countries from Vet360
      # List of countries is available under the countries property with the structure
      # { "country_name": "Afghanistan",
      #   "country_code_iso2": "AF",
      #   "country_code_iso3": "AFG",
      #   "country_code_fips": "AF" }
      # @return [Vet360::ReferenceData::CountriesResponse] response wrapper around array of countries
      def countries
        with_monitoring do
          Vet360::ReferenceData::CountriesResponse.from(perform(:get, 'countries'))
        end
      rescue StandardError => e
        handle_error(e)
      end

      # GETs a the list of valid states from Vet360
      # List of states is available under the states property with the strutcture
      # { "state_name": "Ohio", "state_code": "OH" }
      # @return [Vet360::ReferenceData::StatesResponse] response wrapper around array of states
      def states
        with_monitoring do
          Vet360::ReferenceData::StatesResponse.from(perform(:get, 'states'))
        end
      rescue StandardError => e
        handle_error(e)
      end

      # GETs a the list of valid zipcodes from Vet360
      # List of zipcodes is available under the zipcodes property with the structure
      # { "zip_code": "12345" }
      # @return [Vet360::ReferenceData::ZipcodesResponse] response wrapper around array of states
      def zipcodes
        with_monitoring do
          Vet360::ReferenceData::ZipcodesResponse.from(perform(:get, 'zipcode5'))
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
