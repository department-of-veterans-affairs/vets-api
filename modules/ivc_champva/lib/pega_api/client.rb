# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module IvcChampva
  module PegaApi
    class PegaApiError < StandardError; end

    class Client < Common::Client::Base
      configuration IvcChampva::PegaApi::Configuration

      ##
      # HTTP POST call to the Pega API to retrieve a report
      #
      # @param date_start [Date, nil] the start date of the report
      # @param date_end [Date, nil] the end date of the report
      # @return [Array<Hash>] the report rows
      def get_report(date_start, date_end)
        resp = connection.post(config.base_path) do |req|
          req.headers = headers(date_start, date_end)
        end

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        # We also need to check the StatusCode in the response body.
        # It seems that when this API errors out, it will return responses with HTTP 200 statuses, but
        # the StatusCode in the response body will be something other than 200.
        response = JSON.parse(resp.body, symbolize_names: false)
        unless response['statusCode'] == 200
          raise "alternate response code: #{response['statusCode']}, response body: #{response['body']}"
        end

        # With both status codes checked and passing, we should now have a body that is more JSON embedded in a string.
        # This is our report, let's decode it.
        JSON.parse(response['body'])
      rescue => e
        raise PegaApiError, e.message.to_s
      end

      ##
      # Assembles headers for the Pega API request
      #
      # @param date_start [Date, nil] the start date of the report
      # @param date_end [Date, nil] the end date of the report
      # @return [Hash] the headers
      def headers(date_start, date_end)
        {
          :content_type => 'application/json',
          'x-api-key' => Settings.ivc_champva.pega_api.api_key.to_s,
          'date_start' => date_start.to_s,
          'date_end' => date_end.to_s,
          'case_id' => '' # case_id seems to have no effect, but it is required by the API
        }
      end
    end
  end
end
