# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def build_error
      custom_error = if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError
                       { 'messages' => [{ 'key' => 'ServiceException', 'detail' => 'test detail', status: '500' }] }

                     elsif @error.is_a?(::Common::Exceptions::BackendServiceException) # missing bracket on form_data
                       { 'messages' => [{ 'key' => 'BackendException',
                                          'detail' => 'Backend exception', status: '500' }] }

                     elsif @error.is_a?(StandardError) # when client_key is blank
                       { 'messages' => [{ 'key' => 'Client error', 'detail' => 'client exception', status: '400' }] }

                     else
                       { 'messages' => [{ 'key' => 'Unknown error', 'detail' => 'unknown error', status: '500' }] }

                     end
      update_claim(custom_error)
      log_outcome_for_claims_api(custom_error)
      raise EVSS::DisabilityCompensationForm::ServiceException, custom_error
    end

    def update_claim(custom_error)
      @claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      @claim.evss_response = custom_error['message']
      @claim.save
    end

    def log_outcome_for_claims_api(custom_error)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "claims_api-526-#{@method},  custom_error: #{custom_error}", claim: @claim&.id)
    end
  end
end
