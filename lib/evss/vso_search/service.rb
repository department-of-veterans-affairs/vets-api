# frozen_string_literal: true

module EVSS
  module VsoSearch
    class Service < EVSS::Service
      configuration EVSS::VsoSearch::Configuration

      def initialize(headers)
        @headers = headers
      end

      def get_current_info
        with_monitoring_and_error_handling do
          perform(:post, 'getCurrentInfo', nil, headers).body
        end
      end
    end
  end
end
