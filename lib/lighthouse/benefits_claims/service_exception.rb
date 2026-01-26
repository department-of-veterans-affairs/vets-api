# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'
require 'vets/shared_logging'

module BenefitsClaims
  # Custom exception that maps Benefits Claims errors to error details defined in config/locales/exceptions.en.yml
  #
  class ServiceException
    include Vets::SharedLogging

    ERROR_MAP = {
      504 => Common::Exceptions::GatewayTimeout,
      503 => Common::Exceptions::ServiceUnavailable,
      502 => Common::Exceptions::BadGateway,
      500 => Common::Exceptions::ExternalServerInternalServerError,
      429 => Common::Exceptions::TooManyRequests,
      422 => Common::Exceptions::UnprocessableEntity,
      413 => Common::Exceptions::PayloadTooLarge,
      404 => Common::Exceptions::ResourceNotFound,
      403 => Common::Exceptions::Forbidden,
      401 => Common::Exceptions::Unauthorized,
      400 => Common::Exceptions::BadRequest
    }.freeze

    def initialize(response)
      raise response unless response.is_a?(Hash) && response.key?(:status)

      status = response[:status].to_i
      errors = extract_errors_from_response(response, status)
      raise_exception(status, errors)
    end

    private

    def raise_exception(status, errors)
      raise ArgumentError, "Unmapped status code: #{status}" unless ERROR_MAP.include?(status)

      raise ERROR_MAP[status].new(errors:)
    end

    # Extracts error details from the Lighthouse API response body.
    # Preserves the original error information (title, detail, code, source)
    # instead of falling back to generic i18n messages.
    def extract_errors_from_response(response, status)
      body = response[:body]
      return nil unless body.is_a?(Hash)

      errors = body['errors']
      if errors.is_a?(Array) && errors.any?
        errors.map { |error| transform_error(error, status) }
      else
        # Handle non-standard error response formats
        [transform_error(body, status)]
      end
    end

    def transform_error(error_hash, status)
      return { status: status.to_s } unless error_hash.is_a?(Hash)

      {
        status: (error_hash['status'] || status).to_s,
        title: error_hash['title'],
        detail: error_hash['detail'] || error_hash['message'] || error_hash['error'],
        code: error_hash['code'] || status.to_s,
        source: error_hash['source']
      }.compact
    end
  end
end
