# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def build_error # rubocop:disable Metrics/MethodLength
      get_status
      get_code
      get_source
      if @error.is_a?(Faraday::ConnectionFailed) || @error.is_a?(Faraday::ParsingError) ||
         @error.is_a?(Faraday::NilStatusError) || @error.is_a?(Faraday::TimeoutError) ||
         @error.is_a?(::Common::Exceptions::ExternalServerInternalServerError) ||
         @error.is_a?(::Common::Exceptions::BadGateway) || @error.is_a?(Faraday::SSLError) ||
         @error.is_a?(Faraday::ServerError)
        errors = { errors: [{ 'title' => 'Service Exception',
                              'key' => @source,
                              'detail' => 'A re-tryable error has occurred, original_error: ' \
                                          "#{@error}.", status: @status, code: @code }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::ServiceError, errors

      elsif @error.is_a?(StandardError) || @error.is_a?(Faraday::BadRequestError) ||
            @error.is_a?(::Common::Exceptions::BackendServiceException) ||
            @error.is_a?(Faraday::ConflictError) || @error.is_a?(Faraday::ForbiddenError) ||
            @error.is_a?(Faraday::ProxyAuthError) || @error.is_a?(Faraday::ResourceNotFound) ||
            @error.is_a?(Faraday::UnauthorizedError) || @error.is_a?(Faraday::UnprocessableEntityError) ||
            @error.is_a?(Faraday::ClientError)

        errors = { errors: [{ 'title' => 'Client error',
                              'key' => @source,
                              'detail' => 'A client exception has occurred, job will not be re-tried. ' \
                                          "original_error: #{@error}.", status: '400', code: '400' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::BadRequest, errors
      else
        errors = { errors: [{ 'title' => 'Unknown error',
                              'key' => @source,
                              'detail' => 'An unknown error has occurred, and the custom_error file may ' \
                                          "need to be modified. original_error: #{@error}.", status: @status,
                              code: @code }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::ServiceError, errors
      end
    end

    private

    def log_outcome_for_claims_api(errors)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "claims_api-526-#{@method},  errors: #{errors}", claim: @claim&.id)
    end

    def get_status
      @status = if @error.respond_to?(:status)
                  @error.status
                elsif @error.respond_to?(:status_code)
                  @error.status_code
                else
                  '500'
                end
    end

    def get_code
      @code = if @error.respond_to?(:va900?)
                'VA900'
              elsif @error.respond_to?(:status_code)
                @error.status_code
              else
                @status
              end
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
