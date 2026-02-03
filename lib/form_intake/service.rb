# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'form_intake/configuration'
require 'form_intake/service_error'

module FormIntake
  # Service class for GCIO->IBM structured form data API integration
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration FormIntake::Configuration

    STATSD_KEY_PREFIX = 'api.form_intake'

    # Submit form data to GCIO digitization API
    #
    # @param payload [Hash] Form data in GCIO/IBM format
    # @param benefits_intake_uuid [String] Lighthouse UUID for correlation
    # @return [Hash] Response from GCIO API
    # @raise [FormIntake::ServiceError] on API errors
    def submit_form_data(payload, benefits_intake_uuid)
      # See https://staging.digitization.gcio.com/va/upload/api/swagger/index.html#/Form%20Validation%20Service/putValidatedForm
      with_monitoring do
        response = perform(
          :put,
          "#{FormIntake::Configuration.instance.service_path}/#{benefits_intake_uuid}",
          payload,
          request_headers(benefits_intake_uuid)
        )

        parse_response(response)
      end
    rescue Common::Client::Errors::ClientError => e
      handle_client_error(e)
    rescue Common::Exceptions::GatewayTimeout => e
      raise ServiceError.new("Request timeout: #{e.message}", 504)
    rescue Faraday::ConnectionFailed => e
      raise ServiceError.new("Connection failed: #{e.message}", 503)
    rescue => e
      raise ServiceError.new("Unexpected error: #{e.message}", 500)
    end

    private

    def request_headers(benefits_intake_uuid)
      {
        'X-Benefits-Intake-UUID' => benefits_intake_uuid,
        'X-VA-Source' => 'vets-api'
      }
    end

    def parse_response(response)
      body = JSON.parse(response.body)
      {
        status: response.status,
        body: response.body,
        submission_id: body.dig('data', 'id'),
        tracking_number: body.dig('data', 'attributes', 'tracking_number')
      }
    end

    def handle_client_error(error)
      status = error.status || 500
      body = JSON.parse(error.body)
      message = body.dig('errors', 0, 'detail') || error.message

      Rails.logger.error(
        'Form Intake GCIO API client error',
        status:,
        message:,
        body: error.body
      )

      raise ServiceError.new(message, status)
    end
  end
end
