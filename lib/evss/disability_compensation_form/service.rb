# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module DisabilityCompensationForm #526
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::DisabilityCompensationForm::Configuration

      def get_rated_disabilities
        with_monitoring do
          raw_response = perform(:get, 'ratedDisabilities')
          RatedDisabilitiesResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def submit_form

      end

      def validate_form

      end

      private

      def handle_error(error)
        require 'pry'
        binding.pry
      end
    end
  end
end
