# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module DisabilityCompensationForm
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::DisabilityCompensationForm::Configuration

      def get_rated_disabilities
        with_monitoring do
          raw_response = perform(:get, 'ratedDisabilities')
          RatedDisabilitiesResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def submit_form(form_content)
        with_monitoring do
          headers = { 'Content-Type' => 'application/json' }
          raw_response = perform(:post, 'submit', form_content, headers)
          FormSubmitResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
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
