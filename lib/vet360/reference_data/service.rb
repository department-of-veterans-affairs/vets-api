# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ReferenceData
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ReferenceData::Configuration

      # GETs a the list of valid countries from Vet360
      # List of countries is available under the reference_data property with the structure
      # { "country_name": "Afghanistan",
      #   "country_code_iso2": "AF",
      #   "country_code_iso3": "AFG",
      #   "country_code_fips": "AF" }
      # @return [Vet360::ReferenceData::Response] response wrapper around array of countries
      def countries
        get_reference_data('countries', 'country_list')
      end

      # GETs a the list of valid states from Vet360
      # List of states is available under the reference_data property with the strutcture
      # { "state_name": "Ohio", "state_code": "OH" }
      # @return [Vet360::ReferenceData::Response] response wrapper around array of states
      def states
        get_reference_data('states', 'state_list')
      end

      # GETs a the list of valid zipcodes from Vet360
      # List of zipcodes is available under the reference_data property with the structure
      # { "zip_code": "12345" }
      # @return [Vet360::ReferenceData::Response] response wrapper around array of states
      def zipcodes
        get_reference_data('zipCode5', 'zip_code5_list').tap do |resp|
          zipcodes = resp.reference_data.map do |data|
            { 'zip_code' => data['zip_code5'] }
          end

          resp.reference_data = zipcodes
        end
      end

      private

      def get_reference_data(route, key)
        response = perform(:get, route)
        Vet360::ReferenceData::Response.from(response, key)
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
