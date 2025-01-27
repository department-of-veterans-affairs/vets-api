# frozen_string_literal: true

module Lighthouse
  # Custom exception that maps Lighthouse API errors to controller ExceptionHandling-friendly format
  #
  class ServiceException
    extend SentryLogging

    # a map of the known Lighthouse errors based on the documentation
    # https://developer.va.gov/
    ERROR_MAP = {
      504 => Common::Exceptions::GatewayTimeout,
      503 => Common::Exceptions::ServiceUnavailable,
      502 => Common::Exceptions::BadGateway,
      501 => Common::Exceptions::NotImplemented,
      500 => Common::Exceptions::ExternalServerInternalServerError,
      499 => Common::Exceptions::ClientDisconnected,
      429 => Common::Exceptions::TooManyRequests,
      422 => Common::Exceptions::UnprocessableEntity,
      413 => Common::Exceptions::PayloadTooLarge,
      404 => Common::Exceptions::ResourceNotFound,
      403 => Common::Exceptions::Forbidden,
      401 => Common::Exceptions::Unauthorized,
      400 => Common::Exceptions::BadRequest
    }.freeze

    # sends error logs to sentry that contains the client id and url that the consumer was trying call
    # raises an error based off of what the response status was
    # formats the Lighthouse exception for the controller ExceptionHandling to report out to the consumer
    # @option options [string] :invoker where this method was called from
    def self.send_error(error, service_name, lighthouse_client_id, url, options = {})
      send_error_logs(error, service_name, lighthouse_client_id, url, options)
      return error unless error.respond_to?(:response)

      response = error.response
      status_code = get_status_code(response)
      raise missing_http_status_server_error(error) unless status_code

      errors = get_errors_from_response(error, status_code) if json_response?(response)
      raise error_class(status_code).new(errors:)
    end

    def self.missing_http_status_server_error(error)
      if error.instance_of?(Faraday::TimeoutError)
        # we've seen this Faraday error in production so we're adding this to categorize it
        Common::Exceptions::Timeout.new(errors: [{ title: error.class, detail: error.message }])
      else
        # we're not sure if there are other uncategorized errors, so we're adding this to catch any
        Common::Exceptions::ServiceError.new(errors: [{ title: error.class, detail: error.message }])
      end
    end

    # chooses which error class should be reported based on the http status
    def self.error_class(status_code)
      return Common::Exceptions::ServiceError unless ERROR_MAP.include?(status_code)

      ERROR_MAP[status_code]
    end

    # extracts and transforms Lighthouse errors into the evss_errors schema for the
    # controller ExceptionHandling class
    def self.get_errors_from_response(error, status_code)
      errors = error.response[:body]['errors']

      if errors&.any?
        errors.map do |e|
          status, title, detail, code = error_object_details(e, status_code)

          transform_error_keys(e, status, title, detail, code)
        end
      else
        error_body = error.response[:body]

        status, title, detail, code = error_object_details(error_body, status_code)

        [transform_error_keys(error_body, status, title, detail, code)]
      end
    end

    # error details that match the evss_errors response schema
    # uses known fields in the Lighthouse errors such as "title", "code", "detail", "message", "error"
    # used to get more information from Lighthouse errors in the controllers
    def self.error_object_details(error_body, status_code)
      status = status_code.to_s
      title = error_body['title'] || error_class(status_code).to_s
      detail = error_body['detail'] ||
               error_body['message'] ||
               error_body['error'] ||
               error_body['error_description'] ||
               'No details provided'
      code = error_body['code'] || status

      [status, title, detail, code]
    end

    # transform error hash keys into symbols for controller ExceptionHandling class
    def self.transform_error_keys(error_body, status, title, detail, code)
      error_body
        .merge({ status:, code:, title:, detail: })
        .transform_keys(&:to_sym)
    end

    # log errors
    def self.send_error_logs(error, service_name, lighthouse_client_id, url, options = {})
      logging_options = { url:, lighthouse_client_id: }

      if error.respond_to?(:response) && error.response.present?
        logging_options[:status] = error.response[:status]
        logging_options[:body] = error.response[:body]
      else
        logging_options[:message] = error.message
        logging_options[:backtrace] = error.backtrace
      end

      logging_options[:invoker] = options[:invoker] if options[:invoker]

      log_to_rails_logger(service_name, logging_options)

      extra_context = Sentry.set_extras(
        message: error.message,
        url:,
        client_id: lighthouse_client_id
      )

      tags_context = Sentry.set_tags(external_service: service_name)

      log_exception_to_sentry(error, extra_context, tags_context)
    end

    def self.log_to_rails_logger(service_name, options)
      Rails.logger.error(
        service_name,
        options
      )
    end

    def self.get_status_code(response)
      return response.status if response.respond_to?(:status)

      response[:status] if response.instance_of?(Hash) && response&.key?(:status)
    end

    def self.json_response?(response)
      format = response_type(response)
      format&.include? 'application/json'
    end

    def self.response_type(response)
      return response[:headers]['content-type'] if response[:headers]

      response.headers['content-type'] if response.respond_to?(:headers)
    end
  end
end
