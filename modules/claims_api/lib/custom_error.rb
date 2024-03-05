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
      if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError ||
         @error == Faraday::NilStatusError || @error == Faraday::TimeoutError ||
         @error == ::Common::Exceptions::BackendServiceException ||
         @error == ::Common::Exceptions::ExternalServerInternalServerError ||
         @error == ::Common::Exceptions::BadGateway || @error == Faraday::SSLError ||
         @error == Faraday::ServerError
        errors = { errors: [{ 'title' => 'Service Exception',
                              'detail' => 'A re-tryable error has occurred, original_error: ' \
                                          "#{@error}.", status: @status, code: @code }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::ServiceError, errors

      elsif @error.is_a?(StandardError) || @error == Faraday::BadRequestError ||
            @error == Faraday::ConflictError || @error == Faraday::ForbiddenError ||
            @error == Faraday::ProxyAuthError || @error == Faraday::ResourceNotFound ||
            @error == Faraday::UnauthorizedError || @error == Faraday::UnprocessableEntityError ||
            @error == Faraday::ClientError

        errors = { errors: [{ 'title' => 'Client error',
                              'detail' => 'A client exception has occurred, job will not be re-tried. ' \
                                          "original_error: #{@error}.", status: '400', code: '400' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::BadRequest, errors
      else
        errors = { errors: [{ 'title' => 'Unknown error',
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
  end
end
