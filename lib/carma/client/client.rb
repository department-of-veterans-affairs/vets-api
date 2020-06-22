# frozen_string_literal: true

require 'common/client/base'

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
        # TODO: validate payload schema
        client = get_client

        response_body = with_monitoring do
          client.post(
            '/services/apexrest/carma/v1/1010-cg-submissions',
            payload,
            'Content-Type': 'application/json',
            'Sforce-Auto-Assign': 'FALSE'
          ).body
        end

        response_body
      end

      def create_submission_stub(_payload)
        # TODO: validate payload schema
        {
          'message' => 'Application Received',
          'data' => {
            'carmacase' => {
              'id' => 'aB935000000F3VnCAK',
              'createdAt' => DateTime.now.iso8601
            }
          }
        }
      end

      def create_attachment(payload)
        client = get_client

        response_body = with_monitoring do
          client.post(
            '/services/data/v47.0/sobjects/ContentVersion',
            payload,
            'Content-Type': 'application/json'
          ).body
        end

        response_body
      end

      def create_attachment_stub(_payload)
        {
          'data' => 'Schema TBD' # TODO: record VCR
        }
      end
    end
  end
end
