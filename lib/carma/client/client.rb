# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require 'salesforce/service'

module CARMA
  module Client
    class Client < Salesforce::Service
      configuration CARMA::Client::Configuration

      STATSD_KEY_PREFIX = 'api.carma'
      SALESFORCE_INSTANCE_URL = Settings['salesforce-carma'].url

      CONSUMER_KEY = Settings['salesforce-carma'].consumer_key
      SIGNING_KEY_PATH = Settings['salesforce-carma'].signing_key_path
      SALESFORCE_USERNAME = Settings['salesforce-carma'].username

      def create_submission(payload)
        with_monitoring do
          restforce.post(
            '/services/apexrest/carma/v1/1010-cg-submissions',
            payload,
            'Content-Type': 'application/json',
            'Sforce-Auto-Assign': 'FALSE'
          ) do |req|
            req.options.timeout = 120 # open/read timeout in seconds
          end.body
        end
      end

      def upload_attachments(payload)
        with_monitoring do
          restforce.post(
            '/services/data/v47.0/composite/tree/ContentVersion',
            payload,
            'Content-Type': 'application/json'
          ).body
        end
      end

      private

      def restforce
        return @client if @client.present?

        @client = get_client
        if Settings['salesforce-carma'].mock
          @client.builder.insert_before(0, Faraday::Adapter::NetHttp, Betamocks::Middleware)
        end

        @client
      end
    end
  end
end
