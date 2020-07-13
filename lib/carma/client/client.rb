# frozen_string_literal: true

require 'common/client/base'

module CARMA
  module Client
    class Client < Salesforce::Service
      include Singleton

      configuration CARMA::Client::Configuration

      STATSD_KEY_PREFIX = 'api.carma'
      SALESFORCE_INSTANCE_URL = Settings['salesforce-carma'].url

      CONSUMER_KEY = Settings['salesforce-carma'].consumer_key
      SIGNING_KEY_PATH = Settings['salesforce-carma'].signing_key_path
      SALESFORCE_USERNAME = Settings['salesforce-carma'].username

      def create_submission(payload)
        with_monitoring do
          client.post(
            '/services/apexrest/carma/v1/1010-cg-submissions',
            payload,
            'Content-Type': 'application/json',
            'Sforce-Auto-Assign': 'FALSE'
          ).body
        end
      end

      # Used for Feature Flipper :stub_carma_responses
      def create_submission_stub(_payload)
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

      def upload_attachments(payload)
        with_monitoring do
          client.post(
            '/services/data/v47.0/composite/tree/ContentVersion',
            payload,
            'Content-Type': 'application/json'
          ).body
        end
      end

      # Used for Feature Flipper :stub_carma_responses
      def upload_attachments_stub(_payload)
        {
          'hasErrors' => false,
          'results' => [
            {
              'referenceId' => '1010CG',
              'id' => '06835000000YpsjAAC'
            }
          ]
        }
      end

      private

      def client
        @client ||= get_client
      end
    end
  end
end
