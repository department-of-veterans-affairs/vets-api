# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module IvcChampva
  module VesApi
    class VesApiError < StandardError; end

    # TODO define Message response structure

    class Client < Common::Client::Base
      configuration IvcChampva::VesApi::Configuration

      ##
      # HTTP POST call to the VES VFMP CHAMPVA Application service to submit a 10-10d application.
      #
      # @param transaction_uuid [string] the UUID for the application
      # @param acting_user [string, nil] the acting user for the application
      # @return [Array<Message>] the report rows
      def submit_1010d(transaction_uuid, acting_user)
        resp = connection.post(config.base_path) do |req|
          req.headers = headers(transaction_uuid, acting_user)
        end

        # TODO check for non-200 responses and handle them appropriately

        # TODO parse and return response messages, if we have a use for them?
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
          'apiKey' => Settings.ivc_champva.ves_api.api_key.to_s,
          'transactionUUId' => transaction_uuid.to_s,
          'acting-user' => acting_user.to_s,
        }
      end
    end
  end
end
