# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def handle_errors
      case @error
      when Faraday::ParsingError
        raise_backend_exception('EVSS502', @error.class, @error)
      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @error&.original_status == 403

        raise_backend_exception('EVSS400', @error.class, @error) if @error&.original_status == 400
        raise ::Common::Exceptions::Unauthorized if @error&.original_status == 401
      else
        raise @error
      end
    end

    private

    def get_error_details(key)
      @all_errors = []
      @error.original_body.each do |err|
        symbolized_error = err.deep_symbolize_keys
        severity = symbolized_error[:severity] || nil
        detail = symbolized_error[:detail] || nil
        text = symbolized_error[:text] || nil

        formatted_error = {
          key:,
          severity:,
          detail:,
          text:
        }

        @all_errors << formatted_error
      end
    end

    def raise_backend_exception(key, source, error = nil)
      get_error_details(key)

      raise ::Common::Exceptions::BackendServiceException.new(
        key,
        { source: },
        error&.original_status,
        @all_errors
      )
    end
  end
end
