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
        raise_backend_exception('EVSS502', @error)
      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @error&.original_status == 403

        raise_backend_exception('EVSS400', @error) if @error&.original_status == 400
        raise ::Common::Exceptions::Unauthorized if @error&.original_status == 401
      else
        raise @error
      end
    end

    private

    def raise_backend_exception(_key, error = nil)
      org_body = @error.original_body.deep_symbolize_keys if @error.original_body
      formatted_key = if org_body[:messages][0][:key].present?
                        org_body[:messages][0][:key].gsub('.', '/')
                      elsif org_body[0].present?
                        org_body[0][:key].gsub('.', '/')
                      else
                        @error.key
                      end
      raise ::Common::Exceptions::BackendServiceException.new(
        key,
        { source: formatted_key },
        error&.original_status,
        error&.original_body
      )
    end
  end
end
