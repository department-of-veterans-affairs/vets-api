# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ReferenceData
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ReferenceData::Configuration

      def countries
        get_reference_data('countries')
      end

      def states
        get_reference_data('states')
      end

      def zipcodes
        get_reference_data('zipCode5')
      end

      def get_reference_data(path)
        response = perform(:get, path)
        ReferenceDataResponse.from(response)
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
