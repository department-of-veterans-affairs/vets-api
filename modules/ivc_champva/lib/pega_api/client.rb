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

      ##
      # Checks if a provided IvcChampvaForm record has a corresponding PEGA report
      #
      # @param record [IvcChampvaForm] the form record to check against the PEGA reporting API
      # @return [Hash|boolean] Either a single PEGA report or `false` (if no report was found)
      def record_has_matching_report(record)
        # A report looks like: 
        # {
        #   "Creation Date"=>"2024-12-17T07:42:28.307000", 
        #   "PEGA Case ID"=>"D-XXXXX",
        #   "Status"=>"Processed"
        # }

        # Querying by date requires a window of at least 1 day:
        date_start = record.created_at.strftime('%m/%d/%Y')
        date_end = (record.created_at + 1.day).strftime('%m/%d/%Y')
        # There should only be one match per case ID, so query reports and grab 0th item:
        # TODO:
        #  In practice this won't actually work, because any report with a `nil`
        #  `pega_status` on our side won't actually have a `case_id` to filter by...
        #  what we REALLY need is to add the `form_uuid` property into the PEGA reports
        report = get_report(date_start, date_end).select { |rep| rep['PEGA Case ID'] == record.case_id }[0]
        # If a report exists, return the IVC record and the corresponding report
        # otherwise, return false
        record && report ? report : false
      end
    end
  end
end
