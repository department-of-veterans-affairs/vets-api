# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'pagerduty/configuration'
require 'pagerduty/service'
require_relative 'response'

module PagerDuty
  module ExternalServices
    class Service < PagerDuty::Service
      include Common::Client::Concerns::Monitoring

      # Equivalent to 'External:'
      QUERY = CGI.escape(Settings.maintenance.service_query_prefix)
      LIMIT = 100

      configuration PagerDuty::Configuration

      # Calls PagerDuty's GET /services endpoint, and returns a pre-serialized
      # representation of the raw response.
      #
      # @return [PagerDuty::ExternalServices::Response] A class that wraps a
      #   pre-serialized array of PagerDuty::Models::Service hashes
      # @see https://api-reference.pagerduty.com/#!/Services/get_services
      #
      def get_services
        with_monitoring do
          raw_response = perform(:get, "/services?limit=#{LIMIT}&query=#{QUERY}")

          PagerDuty::ExternalServices::Response.from(raw_response)
        end
      end
    end
  end
end
