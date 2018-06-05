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

      def get_reference_data(path, key)
        response = perform(:get, path)
        ReferenceDataResponse.new(response.status, data: response.body[key])
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
