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

      # The CARMA Staging and Prod enviornments will not exist until ~May 2020
      # So we will not be hitting SALESFORCE_INSTANCE_URL in runtime, to avoid 500 errors. Instead
      # we'll use stub req/res in order to do user testing on the rest of our submission code.
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
    end
  end
end
