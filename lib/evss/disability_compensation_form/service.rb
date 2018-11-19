# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative '../disability_compensation_auth_headers.rb'

module EVSS
  module DisabilityCompensationForm
    class Service < EVSS::Service
      configuration EVSS::DisabilityCompensationForm::Configuration

      def initialize(headers)
        @headers = headers
      end

      def get_rated_disabilities
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'ratedDisabilities')
          RatedDisabilitiesResponse.new(raw_response.status, raw_response)
        end
      end

      def submit_form526(form_content)
        with_monitoring_and_error_handling do
          headers = { 'Content-Type' => 'application/json' }
          raw_response = perform(:post, 'submit', form_content, headers)
          FormSubmitResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::DisabilityCompensationForm::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
