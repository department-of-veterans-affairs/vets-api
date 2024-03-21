# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def handle_errors
      get_source
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

    def raise_backend_exception(key, error = nil)
      raise ::Common::Exceptions::BackendServiceException.new(
        key,
        { source: @source.to_s },
        error&.original_status,
        error&.original_body
      )
    end

    def get_source
      if (@error.respond_to?(:key) && @error.key.present?) ||
         (@error.respond_to?(:backtrace) && @error.backtrace.present?)
        matches = if @error.backtrace.nil? && @error.key.present?
                    @error.key[0].match(/vets-api(\S*) (.*)/)
                  elsif @error.backtrace.present?
                    @error.backtrace[0].match(/vets-api(\S*) (.*)/)
                  end
        @source = matches[0].split(':')[0] || self.class
      end
    end
  end
end
