# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def build_error # rubocop:disable Metrics/MethodLength
      if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError
        errors = { :errors => [{ 'key' => 'ServiceException',
                                     'detail' => 'A Faraday error has occurred, original_error: ' \
                                                 "#{@error}.", status: '500' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::ServiceError.new(errors)

      elsif @error.is_a?(::Common::Exceptions::BackendServiceException)
        errors = { :errors => [{ 'key' => 'BackendException',
                                     'detail' => 'A backend exception occurred, original_error: ' \
                                                 "#{@error}.", status: '500' }] }
        log_outcome_for_claims_api(errors)
        debugger
        raise ::Common::Exceptions::ServiceError.new(errors)
      elsif @error.is_a?(StandardError)
        errors = { :errors => [{ 'key' => 'Client error',
                                     'detail' => 'A client exception has occurred, original_error: ' \
                                                 "#{@error}.", status: '400' }] }
        log_outcome_for_claims_api(errors)
        raise ::Common::Exceptions::BadRequest.new(errors)
      else
        errors = { :errors => [{ 'key' => 'Unknown error',
                                     'detail' => 'An unknown error has occurred, original_error: ' \
                                                 "#{@error}.", status: '500' }] }
                                                 log_outcome_for_claims_api(errors)
                                                 raise ::Common::Exceptions::ServiceError.new(errors)
                                                end
    end

    def log_outcome_for_claims_api(errors)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "claims_api-526-#{@method},  errors: #{errors}", claim: @claim&.id)
    end
  end
end
