# frozen_string_literal: true

require 'claims_api/common/exceptions/lighthouse/backend_service_exception'
require 'claims_api/v2/error/lighthouse_error_mapper'
module ClaimsApi
  class CustomError
    def initialize(error, async = true) # rubocop:disable Style/OptionalBooleanParameter
      @error = error
      @async = async
      @original_status = @error&.original_status if @error&.methods&.include?(:original_status)
      @original_body = @error&.original_body if @error&.methods&.include?(:original_body)
    end

    def build_error
      case @error
      when Faraday::ParsingError
        raise_backend_exception(@error.class, @error, 'EVSS502')
      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @error&.original_status == 403

        raise_backend_exception('EVSS400') if @error&.original_status == 400
        raise ::Common::Exceptions::Unauthorized if @error&.original_status == 401

        raise_backend_exception('EVSS500')
      else
        raise @error
      end
    end

    private

    def raise_backend_exception(_key = 'EVSS')
      error_details = get_error_info
      raise ::ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException, error_details
    end

    def get_error_info
      all_errors = []

      @original_body&.[](:messages)&.each do |err|
        symbolized_error = err.deep_symbolize_keys
        all_errors << collect_errors(symbolized_error)
      end
      all_errors
    end

    def collect_errors(symbolized_error)
      details = get_details(symbolized_error)
      severity = symbolized_error[:severity] || nil
      detail = details || nil
      text = symbolized_error[:text] || nil
      key = symbolized_error[:key] || nil
      {
        key:,
        severity:,
        detail:,
        text:
      }
    end

    def get_details(error)
      if @async
        error[:text]
      else
        ClaimsApi::V2::Error::LighthouseErrorMapper.new(error).get_details
      end
    end
  end
end
