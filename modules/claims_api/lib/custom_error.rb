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
        custom_error = { 'messages' => [{ 'key' => 'ServiceException',
                                          'detail' => 'A Faraday error has occurred.', status: '500' }] }
        update_claim(custom_error)
        raise EVSS::DisabilityCompensationForm::ServiceException, custom_error

      elsif @error.is_a?(::Common::Exceptions::BackendServiceException) # missing bracket on form_data
        custom_error = { 'messages' => [{ 'key' => 'BackendException',
                                          'detail' => 'A backend exception occurred.', status: '500' }] }
        update_claim(custom_error)
        raise EVSS::DisabilityCompensationForm::ServiceException, custom_error
      elsif @error.is_a?(StandardError) # when client_key is blank
        custom_error = { 'messages' => [{ 'key' => 'Client error',
                                          'detail' => 'A client exception has occurred.', status: '400' }] }
        update_claim(custom_error)
        raise custom_error
      else
        custom_error = { 'messages' => [{ 'key' => 'Unknown error',
                                          'detail' => 'An unknown error has occurred.', status: '500' }] }
        update_claim(custom_error)
        raise custom_error
      end
    end

    def update_claim(custom_error)
      log_outcome_for_claims_api(custom_error)
      @claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      @claim.evss_response = custom_error['messages']
      @claim.save
    end

    def log_outcome_for_claims_api(custom_error)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "claims_api-526-#{@method},  custom_error: #{custom_error}", claim: @claim&.id)
    end
  end
end
