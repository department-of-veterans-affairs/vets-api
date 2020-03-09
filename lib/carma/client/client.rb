# frozen_string_literal: true

require 'common/client/base'

module CARMA
  module Client
    class Client < Salesforce::Service
      configuration CARMA::Client::Configuration

      STATSD_KEY_PREFIX = 'api.carma'
      SALESFORCE_INSTANCE_URL = 'https://va--carmadev.my.salesforce.com'

      CONSUMER_KEY = Settings['salesforce-carma'].consumer_key
      SIGNING_KEY_PATH = Settings['salesforce-carma'].signing_key_path
      SALESFORCE_USERNAME = Settings['salesforce-carma'].username

      def create_submission(payload)
        client = get_client

        response_body = with_monitoring do
          client.post(
            '/services/apexrest/carma/v1/1010-cg-submissions',
            payload,
            'Content-Type': 'application/json'
          ).body
        end

        response_body
      end
    end
  end
end
