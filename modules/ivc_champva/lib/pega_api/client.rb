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
      # @param case_id [string, nil] PEGA case ID of a given submission
      # @param uuid [string, nil] Form UUID of a given submission
      #
      # @return [Array<Hash>] the report rows
      def get_report(date_start, date_end, case_id = '', uuid = '')
        resp = connection.post(config.base_path) do |req|
          req.headers = headers(date_start, date_end, case_id, uuid)
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
      # @param date_start [string, nil] the start date of the report
      # @param date_end [string, nil] the end date of the report
      # @param case_id [string, nil] PEGA case ID of a given submission
      # @param uuid [string, nil] Form UUID of a given submission
      #
      # @return [Hash] the headers
      def headers(date_start, date_end, case_id = '', uuid = '')
        {
          :content_type => 'application/json',
          'x-api-key' => Settings.ivc_champva.pega_api.api_key.to_s,
          'date_start' => date_start.to_s,
          'date_end' => date_end.to_s,
          'case_id' => case_id.to_s,
          'uuid' => uuid.to_s
        }
      end

      ##
      # Checks if a provided IvcChampvaForm record has a corresponding PEGA report
      #
      # @param record [IvcChampvaForm] the form record to check against the PEGA reporting API
      #
      # @return [Hash|boolean] Either a list of PEGA reports or `false` if no report was found
      def record_has_matching_report(record)
        # A report looks like this (note the UUID truncation 'e+'):
        # { "Creation Date"=>"2024-12-17T07:42:28.307000",
        #   "PEGA Case ID"=>"D-XXXXX",
        #   "Status"=>"Processed",
        #   "UUID"=> "78444a0b-3ac8-454d-a28d-8d6f0e+" }

        # Querying by date requires a window of at least 1 day:
        date_start = record.created_at.strftime('%m/%d/%Y')
        date_end = (record.created_at + 1.day).strftime('%m/%d/%Y')
        reports = get_report(date_start, date_end, '', record.form_uuid)

        # If a report exists, return the IVC record and the corresponding report
        # otherwise, return false
        record && reports ? reports : false
      end
    end
  end
end
