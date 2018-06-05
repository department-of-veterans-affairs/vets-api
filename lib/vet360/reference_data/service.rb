# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ReferenceData
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ReferenceData::Configuration

      def countries
        get_reference_data('countries', 'country_list')
      end

      def states
        get_reference_data('states', 'state_list')
      end

      def zipcodes
        get_reference_data('zipcode5', 'zip_code5_list').map do |zip_data|
          { 'zip_code' => zip_data['zip_code5'] }
        end
      end

      def get_reference_data(path, key)
        with_monitoring do
          resp = perform(:get, path)
          resp.body[key]
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
