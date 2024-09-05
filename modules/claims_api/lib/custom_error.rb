# frozen_string_literal: true

require 'claims_api/common/exceptions/lighthouse/backend_service_exception'
require 'claims_api/common/exceptions/lighthouse/bad_gateway'
require 'claims_api/common/exceptions/lighthouse/timeout'
require 'claims_api/v2/error/lighthouse_error_mapper'

module ClaimsApi
  class CustomError
    def initialize(error, detail = nil, async = true) # rubocop:disable Style/OptionalBooleanParameter
      @error = error
      @async = async
      @detail = detail
      @original_status = @error&.original_status if @error&.methods&.include?(:original_status)
      @original_body = get_original_body
    end

    def build_error
      handle_strings if @error.is_a?(String) || @original_body.is_a?(String)

      case @error
      when Faraday::ParsingError
        raise_backend_exception
      when ::Common::Exceptions::GatewayTimeout,
        Timeout::Error,
        Faraday::TimeoutError,
        Breakers::OutageException,
        Net::HTTPGatewayTimeout
        raise_timeout_exception

      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @original_status == 403

        raise_bad_gateway_exception if @original_status == 504
        raise_backend_exception if @original_status == 400
        raise ::Common::Exceptions::Unauthorized if @original_status == 401

        raise_backend_exception
      else
        raise @error
      end
    end

    private

    def raise_backend_exception
      error_details = get_error_info
      raise ::ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException, error_details
    end

    def raise_timeout_exception
      error_details = get_error_info if @original_body.present?
      raise ::ClaimsApi::Common::Exceptions::Lighthouse::Timeout, error_details
    end

    def raise_bad_gateway_exception
      error_details = get_error_info if @original_body.present?
      raise ::ClaimsApi::Common::Exceptions::Lighthouse::BadGateway, error_details
    end

    def get_error_info
      all_errors = []

      @original_body&.fetch(:messages)&.each do |err|
        symbolized_error = err.deep_symbolize_keys
        all_errors << munge_error(symbolized_error) unless symbolized_error[:severity] == 'WARN'
      end
      all_errors
    end

    def munge_error(symbolized_error)
      {
        key: symbolized_error[:key],
        severity: symbolized_error[:severity],
        detail: get_details(symbolized_error),
        text: symbolized_error[:text]
      }
    end

    def get_details(error)
      if @async
        error[:text]
      else
        ClaimsApi::V2::Error::LighthouseErrorMapper.new(error).get_details
      end
    end

    def handle_strings
      @error = ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException.new(
        [{ detail: @error.is_a?(String) ? @error : @original_body, status: 422, title: 'String error' }]
      )
    end

    def get_original_body
      @detail ||= @error&.original_body if @error&.methods&.include?(:original_body)
    end
  end
end
