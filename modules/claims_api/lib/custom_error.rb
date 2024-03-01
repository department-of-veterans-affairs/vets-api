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
      if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError ||
         @error == Faraday::NilStatusError || @error == Faraday::TimeoutError ||
         @error == ::Common::Exceptions::BackendServiceException ||
         @error == ::Common::Exceptions::ExternalServerInternalServerError ||
         @error == ::Common::Exceptions::BadGateway || @error == Faraday::SSLError ||
         @error == Faraday::ServerError || @status.to_s.start_with?('5')
        errors = { errors: [{ 'key' => 'Service Exception',
                              'detail' => 'A re-tryable error has occurred, original_error: ' \
                                          "#{@error}.", status: '500' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::ServiceError, errors

      elsif @error.is_a?(StandardError) || @error == Faraday::BadRequestError ||
            @error == Faraday::ConflictError || @error == Faraday::ForbiddenError ||
            @error == Faraday::ProxyAuthError || @error == Faraday::ResourceNotFound ||
            @error == Faraday::UnauthorizedError || @error == Faraday::UnprocessableEntityError ||
            @error == Faraday::ClientError || @status.to_s.start_with?('4')

        errors = { errors: [{ 'key' => 'Client error',
                              'detail' => 'A client exception has occurred, job will not be re-tried.' \
                                          "original_error: #{@error}.", status: '400' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::BadRequest, errors
      else
        errors = { errors: [{ 'key' => 'Unknown error',
                              'detail' => 'An unknown error has occurred, and the custom_error file may ' \
                                          "need to be modified. original_error: #{@error}.", status: '500' }] }
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
      if @error.respond_to?(:status)
        @status = @error.status
      elsif @error.respond_to?(:status_code)
        @status = @error.status_code
      end
      @status
    end
  end
end
