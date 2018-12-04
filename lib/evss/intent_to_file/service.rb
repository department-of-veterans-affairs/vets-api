# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module IntentToFile
    class Service < EVSS::Service
      configuration EVSS::IntentToFile::Configuration

      ITF_SOURCE = 'VETS.GOV'

      def get_intent_to_file
        with_monitoring_and_error_handling do
          raw_response = perform(:get, '')
          EVSS::IntentToFile::IntentToFilesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_active(itf_type)
        with_monitoring_and_error_handling do
          raw_response = perform(:get, "#{itf_type}/active")
          EVSS::IntentToFile::IntentToFileResponse.new(raw_response.status, raw_response)
        end
      end

      def create_intent_to_file(itf_type)
        with_monitoring_and_error_handling do
          raw_response = perform(:post, itf_type.to_s, { source: ITF_SOURCE }.to_json, headers)
          EVSS::IntentToFile::IntentToFileResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          save_error_details(error)
          raise EVSS::IntentToFile::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
