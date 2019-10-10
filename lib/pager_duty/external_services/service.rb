# frozen_string_literal: true

module PagerDuty
  module ExternalServices
    class Service < PagerDuty::Service
      include Common::Client::Monitoring

      # Equivalent to 'External:'
      QUERY = 'External%3A'
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
