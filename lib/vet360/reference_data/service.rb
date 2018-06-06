# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ReferenceData
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ReferenceData::Configuration

      # GETs a the list of valid countries from Vet360
      # @return [Vet360::ReferenceData::Response] response wrapper
      def countries
        get_reference_data('countries', 'country_list')
      end

      def states
        get_reference_data('states', 'state_list')
      end

      def zipcodes
        get_reference_data('zipCode5', 'zip_code5_list')
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
