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
        raise_backend_exception('EVSS502', self.class)
      when ::Common::Exceptions::BackendServiceException
        raise ::Common::Exceptions::Forbidden if @error&.original_status == 403

        raise_backend_exception('EVSS400', self.class, @error) if @error&.original_status == 400
        raise ::Common::Exceptions::Unauthorized if @error&.original_status == 401
      else
        raise @error
      end
    end

    private

    def raise_backend_exception(key, source, error = nil)
      raise ::Common::Exceptions::BackendServiceException.new(
        key,
        { source: source.to_s },
        error&.original_status,
        error&.original_body
      )
    end

    def get_source
      if (@error.respond_to?(:key) && @error.key.present?) ||
         (@error.respond_to?(:backtrace) && @error.backtrace.present?)
        matches = if @error.backtrace.nil?
                    @error.key[0].match(/vets-api(\S*) (.*)/)
                  else
                    @error.backtrace[0].match(/vets-api(\S*) (.*)/)
                  end
        spliters = matches[0].split(':')
        @source = spliters[0]
      end
    end
  end
end
