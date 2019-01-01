# frozen_string_literal: true

module EVSS
  module VsoSearch
    class Service < EVSS::Service
      configuration EVSS::VsoSearch::Configuration

      def get_current_info
        with_monitoring_and_error_handling do
          raw_response = perform(:post, 'getCurrentInfo')
        end
      end
    end
  end
end
