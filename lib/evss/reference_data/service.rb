# frozen_string_literal: true

require 'evss/jwt'

module EVSS
  module ReferenceData
    class Service < EVSS::Service
      configuration EVSS::ReferenceData::Configuration

      def get_countries
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'countries')
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_states
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'states')
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      private

      # overrides EVSS::Service#headers_for_user
      def headers_for_user(user)
        {
          Authorization: "Bearer #{EVSS::Jwt.new(user).encode}"
        }
      end
    end
  end
end
