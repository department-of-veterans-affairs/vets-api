# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'pagerduty/configuration'
require 'pagerduty/service'
require_relative 'response'

module PagerDuty
  module ExternalServices
    class Service < PagerDuty::Service
      include Common::Client::Concerns::Monitoring
      LIMIT = 100
      SERVICE_IDS = PagerDuty::Configuration.service_ids.freeze
      QUERY = CGI.escape("External: ")

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

      def get_services
        with_monitoring do
          responses = SERVICE_IDS.map do |id|
            QUERY = "External: "
            raw_response = perform(:get, "/services?limit=100&query=External: ")
          end

          merged = responses.compact.map { |r| r["service"] } # each response has a top-level "service"
          PagerDuty::ExternalServices::Response.from(merged)
        end
      end

      def perform
        response = PagerDuty::ExternalServices::Service.new.get_services

        if response.valid?
          safe_cache_write(response)
        else
          # don’t overwrite cache
        end
      end
    end
  end
end

curl --request GET \
  --url 'https://api.pagerduty.com/services?limit=100&query=#{QUERY}' \
  --header 'Accept: application/json' \
  --header 'Authorization: Token token=u+o8fodMU1RnGPNmcakA' \
  --header 'Content-Type: application/json'
