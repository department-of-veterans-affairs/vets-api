# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module IntentToFile
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::IntentToFile::Configuration

      def get_intent_to_file
        with_monitoring do
          raw_response = perform(:get, '')
          EVSS::IntentToFile::IntentToFilesResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def get_active_compensation
        # intent_to_file currently only handles 'compensation'
        # future expansion will include 'pension' and 'survivor' accessible via the path
        with_monitoring do
          get_active('compensation')
        end
      rescue StandardError => e
        handle_error(e)
      end

      def create_intent_to_file_compensation(content)
        # intent_to_file currently only handles 'compensation'
        # future expansion will include 'pension' and 'survivor' accessible via the path
        with_monitoring do
          create_intent_to_file(content, 'compensation')
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      def get_active(type)
        raw_response = perform(:get, "#{type}/active")
        EVSS::IntentToFile::IntentToFileResponse.new(raw_response.status, raw_response)
      end

      def create_intent_to_file(content, type)
        headers = { 'Content-Type' => 'application/json' }
        raw_response = perform(:post, type.to_s, content, headers)
        EVSS::IntentToFile::IntentToFileResponse.new(raw_response.status, raw_response)
      end

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::IntentToFile::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
