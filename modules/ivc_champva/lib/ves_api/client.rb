# frozen_string_literal: true

require 'json'
require 'common/client/base'
require 'ivc_champva/monitor'
require_relative 'configuration'

module IvcChampva
  module VesApi
    class VesApiError < StandardError; end

    # TODO: define Message response structure

    class Client < Common::Client::Base
      configuration IvcChampva::VesApi::Configuration

      def settings
        Settings.ivc_champva_ves_api
      end

      delegate :api_key, to: :settings

      ##
      # HTTP POST call to the VES VFMP CHAMPVA Application service to submit a 10-10d application.
      #
      # @param transaction_uuid [string] the UUID for the application
      # @param acting_user [string, nil] the acting user for the application
      # @param ves_request_data [IvcChampva::VesRequest] preformatted request data
      def submit_1010d(transaction_uuid, acting_user, ves_request_data)
        resp = connection.post("#{config.base_path}/champva-applications") do |req|
          req.headers = headers(transaction_uuid, acting_user)
          req.body = ves_request_data.to_json
        end

        monitor.track_ves_response(transaction_uuid, resp.status, resp.body)

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        resp
      rescue => e
        raise VesApiError, e.message.to_s
      end

      ##
      # Assembles headers for the VES API request
      #
      # @param transaction_uuid [string] the start date of the report
      # @param acting_user [string, nil] the end date of the report
      # @return [Hash] the headers
      def headers(transaction_uuid, acting_user)
        {
          :content_type => 'application/json',
          'apiKey' => settings.api_key,
          'transactionUUId' => transaction_uuid.to_s,
          'acting-user' => acting_user.to_s
        }
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [IvcChampva::Monitor]
      #
      def monitor
        @monitor ||= IvcChampva::Monitor.new
      end
    end
  end
end
