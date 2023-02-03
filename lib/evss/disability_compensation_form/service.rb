# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'evss/service'
require 'evss/disability_compensation_auth_headers'
require_relative 'configuration'
require_relative 'rated_disabilities_response'
require_relative 'form_submit_response'
require_relative 'service_unavailable_exception'

module EVSS
  module DisabilityCompensationForm
    # Proxy Service for EVSS's 526 endpoints. A set of VAAFI headers generated from user
    # data must be passed on initialization so that the calls can be authenticated.
    # The disability compensation service requires additional headers so {EVSS::DisabilityCompensationAuthHeaders}
    # is used to decorate the default EVSS headers {EVSS::AuthHeaders}.
    #
    # @example Create a service
    #   auth_headers = EVSS::AuthHeaders.new(@current_user).to_h
    #   disability_auth_headers = EVSS::DisabilityCompensationAuthHeaders.new(@current_user).add_headers(auth_headers)
    #   EVSS::DisabilityCompensationForm::Service.new(disability_auth_headers)
    #
    class Service < EVSS::Service
      configuration EVSS::DisabilityCompensationForm::Configuration

      # @param headers [EVSS::DisabilityCompensationAuthHeaders] VAAFI headers for a user
      #
      def initialize(headers)
        @headers = headers
        @transaction_id = @headers['va_eauth_service_transaction_id']
      end

      # GETs a user's rated disabilities
      #
      # @return [EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse] Response with a list of rated disabilities
      #
      def get_rated_disabilities
        if @headers['va_eauth_birlsfilenumber'].blank?
          Rails.logger.info('Missing `birls_id`', edipi: @headers['va_eauth_dodedipnid'])
        end
        with_monitoring_and_error_handling do
          Rails.cache.fetch("evss_rated_disabilities/#{@headers['va_eauth_dodedipnid']}-#{@headers['va_eauth_pnid']}",
                            expires_in: 30.minutes) do
            raw_response = perform(:get, 'ratedDisabilities')
            RatedDisabilitiesResponse.new(raw_response.status, raw_response)
          end
        end
      end

      # POSTs a 526 form to the EVSS submit endpoint. EVSS is bound to VBMSs response times and, therefore,
      # the timeout has to be extended to ~6 minutes to match their upstream timeout.
      #
      # @param form_content [JSON] JSON serialized version of a {Form526Submission}
      # @return [EVSS::DisabilityCompensationForm::FormSubmitResponse] Response that includes the EVSS claim_id
      #
      def submit_form526(form_content)
        with_monitoring_and_error_handling do
          headers = { 'Content-Type' => 'application/json' }
          options = { timeout: Settings.evss.disability_compensation_form.submit_timeout || 355 }
          raw_response = perform(:post, 'submit', form_content, headers, options)
          FormSubmitResponse.new(raw_response.status, raw_response)
        end
      end

      # Gets a filled out 526ez PDF from EVSS from the same playload of the submit endpoint.
      # Returns PDF stream in response, instead of submitting to auto-establish.
      # This is used in the 526ez backup submission process when auto-establisment errors and is not possible.
      #
      # @param form_content [JSON] JSON serialized version of a {Form526Submission}
      # @return [Faraday::Response] - Response from EVSS /getPDF endpoint
      def get_form526(form_content)
        with_monitoring_and_error_handling do
          headers = { 'Content-Type' => 'application/json' }
          options = { timeout: Settings.evss.disability_compensation_form.submit_timeout || 355 }
          perform(:post, 'getPDF', form_content, headers, options)
        end
      end

      def validate_form526(form_content)
        with_monitoring_and_error_handling do
          headers = { 'Content-Type' => 'application/json' }
          options = { timeout: Settings.evss.disability_compensation_form.submit_timeout || 355 }
          perform(:post, 'validate', form_content, headers, options)
        end
      end

      private

      def handle_service_unavailable_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status == 503
          raise EVSS::DisabilityCompensationForm::ServiceUnavailableException
        end
      end

      def handle_error(error)
        handle_service_unavailable_error(error)

        # Common::Client::Errors::ClientError is raised from Common::Client::Base#request after it rescues
        # Faraday::ClientError.  EVSS::ErrorMiddleware::EVSSError is raised from EVSS::ErrorMiddleware when
        # there is a 200-response with an error message in the body
        if ((error.is_a?(Common::Client::Errors::ClientError) && error.status != 403) ||
           error.is_a?(EVSS::ErrorMiddleware::EVSSError)) && error.body.is_a?(Hash)
          save_error_details(error) # Sentry extra_context
          raise EVSS::DisabilityCompensationForm::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
