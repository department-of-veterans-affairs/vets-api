# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error)
      @error = error
    end

    def build_error
      case @error
      when Faraday::ParsingError
        raise_backend_exception(@error.class, @error, 'EVSS502')
      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @error&.original_status == 403

        raise_backend_exception(@error.class, @error, 'EVSS400') if @error&.original_status == 400
        raise ::Common::Exceptions::Unauthorized if @error&.original_status == 401
      else
        raise @error
      end
    end

    private

    def raise_backend_exception(source, error, key = 'EVSS')
      error_details = get_error_details(error)

      raise ::Common::Exceptions::BackendServiceException.new(
        key,
        { source: },
        error&.original_status,
        error_details
      )
    end

    def get_error_details(error)
      all_errors = []
      error.original_body[:messages].each do |err|
        symbolized_error = err.deep_symbolize_keys
        all_errors << collect_errors(symbolized_error)
      end
      all_errors
    end

    def collect_errors(symbolized_error)
      severity = symbolized_error[:severity] || nil
      detail = symbolized_error[:detail] || nil
      text = symbolized_error[:text] || nil
      key = symbolized_error[:key] || nil
      {
        key:,
        severity:,
        detail:,
        text:
      }.compact!
    end
  end
end
