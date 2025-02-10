# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'evss/service'
require_relative 'configuration'
require_relative 'intent_to_file_response'
require_relative 'intent_to_files_response'
require_relative 'service_exception'

module EVSS
  module IntentToFile
    ##  # TODO - see if we can remove
    # Proxy Service for Intent To File.
    #
    # @example Create a service and fetching intent to file for a user
    #   itf_response = IntentToFile::Service.new.get_intent_to_file
    #
    class Service < EVSS::Service
      configuration EVSS::IntentToFile::Configuration

      ITF_SOURCE = 'VETS.GOV'

      ##
      # Returns all intents to file for a user
      #
      # @return [EVSS::IntentToFile::IntentToFilesResponse] Object containing
      # an array of intents to file
      #
      def get_intent_to_file
        with_monitoring_and_error_handling do
          raw_response = perform(:get, '')
          EVSS::IntentToFile::IntentToFilesResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # Returns all active intents to file of a particular type
      #
      # @param itf_type [String] Type of intent to file
      # @return [EVSS::IntentToFile::IntentToFilesResponse] Object containing
      # an array of intents to file
      #
      def get_active(itf_type)
        with_monitoring_and_error_handling do
          raw_response = perform(:get, "#{itf_type}/active")
          EVSS::IntentToFile::IntentToFileResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # Creates a new intent to file
      #
      # @param itf_type [String] Type of intent to file
      # @return [EVSS::IntentToFIle::IntentToFileResponse] Intent to file response object
      #
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
