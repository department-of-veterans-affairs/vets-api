# frozen_string_literal: true

module Lighthouse
  # Custom exception that maps Lighthouse API errors to controller ExceptionHandling-friendly format
  #
  class ServiceException
    include SentryLogging

    # a map of the known Lighthouse errors based on the documentation
    # https://developer.va.gov/
    ERROR_MAP = {
      '504': Common::Exceptions::GatewayTimeout,
      '503': Common::Exceptions::ServiceUnavailable,
      '502': Common::Exceptions::BadGateway,
      '500': Common::Exceptions::ExternalServerInternalServerError,
      '429': Common::Exceptions::TooManyRequests,
      '413': Common::Exceptions::PayloadTooLarge,
      '404': Common::Exceptions::ResourceNotFound,
      '403': Common::Exceptions::Forbidden,
      '401': Common::Exceptions::Unauthorized,
      '400': Common::Exceptions::BadRequest
    }.freeze

    # sends error logs to sentry that contains the client id and url that the consumer was trying call
    # raises an error based off of what the response status was
    # formats the Lighthouse exception for the controller ExceptionHandling to report out to the consumer
    def self.send_error(error, service_name, lighthouse_client_id, url)
      raise error_class(:'504') if gateway_timeout?(error.response)

      error_response = error.response.deep_symbolize_keys

      return error unless error_response&.key?(:status)

      send_error_logs(error, service_name, lighthouse_client_id, url)

      error_status = error_response[:status]

      errors = get_errors_from_response(error, error_status)

      error_status_sym = error_status.to_s.to_sym

      raise error_class(error_status_sym).new(errors:)
    end

    # chooses which error class should be reported based on the http status
    def self.error_class(error_status_sym)
      return Common::Exceptions::ServiceError unless ERROR_MAP.include?(error_status_sym)

      ERROR_MAP[error_status_sym]
    end

    # extracts and transforms Lighthouse errors into the evss_errors schema for the
    # controller ExceptionHandling class
    def self.get_errors_from_response(error, error_status = nil)
      errors = error.response[:body]['errors']

      error_status ||= error.response[:status]

      if errors&.any?
        errors.map do |e|
          status, title, detail, code = error_object_details(e, error_status)

          transform_error_keys(e, status, title, detail, code)
        end
      else
        error_body = error.response[:body]

        status, title, detail, code = error_object_details(error_body, error_status)

        [transform_error_keys(error_body, status, title, detail, code)]
      end
    end

    # error details that match the evss_errors response schema
    # uses known fields in the Lighthouse errors such as "title", "code", "detail", "message", "error"
    # used to get more information from Lighthouse errors in the controllers
    def self.error_object_details(error_body, error_status)
      status = error_status&.to_s
      title = error_body['title'] || error_class(status.to_sym).to_s
      detail = error_body['detail'] ||
               error_body['message'] ||
               error_body['error'] ||
               error_body['error_description'] ||
               'No details provided'

      code = error_body['code'] || error_status&.to_s

      [status, title, detail, code]
    end

    # transform error hash keys into symbols for controller ExceptionHandling class
    def self.transform_error_keys(error_body, status, title, detail, code)
      error_body
        .merge({ status:, code:, title:, detail: })
        .transform_keys(&:to_sym)
    end

    # sends errors to sentry!
    def self.send_error_logs(error, service_name, lighthouse_client_id, url)
      base_key_string = "#{lighthouse_client_id} #{url} Lighthouse Error"
      Rails.logger.error(
        error.response,
        base_key_string
      )

      Raven.tags_context(
        external_service: service_name
      )

      Raven.extra_context(
        message: error.message,
        url:,
        client_id: lighthouse_client_id
      )
    end

    def self.gateway_timeout?(response)
      return response.status == 504 if response.respond_to?(:status)
      return response[:status] == 504 if response.instance_of?(Hash) && response&.key?(:status)

      false
    end
  end
end
