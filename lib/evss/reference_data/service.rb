# frozen_string_literal: true

require 'evss/pciu_address/countries_response'
require 'evss/pciu_address/states_response'
require 'evss/service'
require_relative 'configuration'
require_relative 'intake_sites_response'

module EVSS
  module ReferenceData
    class Service < EVSS::Service
      configuration EVSS::ReferenceData::Configuration

      ##
      # Creates an object containing an array of country names
      #
      # @return [EVSS::PCIUAddress::CountriesResponse] Countries response object
      #
      def get_countries
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'countries')
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # Creates an object containing an array of state names
      #
      # @return [EVSS::PCIUAddress::StatesResponse] States response object
      #
      def get_states
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'states')
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_separation_locations
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'intakesites')
          EVSS::ReferenceData::IntakeSitesResponse.new(raw_response.status, raw_response)
        end
      end
    end
  end
end
