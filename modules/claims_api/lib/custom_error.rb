# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error, claim, method)
      @error = error
      @claim = claim
      @method = method
    end

    def build_error
      if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError
        custom_error = { 'messages' => [{ 'key' => 'ServiceException', 'detail' => 'test detail', status: '500' }] }
        update_claim(custom_error)
        log_outcome_for_claims_api(custom_error)

        raise EVSS::DisabilityCompensationForm::ServiceException, custom_error

      # empty client id, missing bracket on form_data are both caught by BackendServiceException
      elsif @error.is_a?(::Common::Exceptions::BackendServiceException) || @error.is_a?(StandardError)
        custom_error = { 'messages' => [{ 'key' => 'BackendException',
                                          'detail' => 'Backend exception or standard error', status: '500' }] }
        update_claim(custom_error)
        log_outcome_for_claims_api(custom_error)

        raise EVSS::DisabilityCompensationForm::ServiceException, custom_error
      # elsif (@error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status == '503') ||
      #       (@error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status != '403') ||
      #       (@error == ::Common::Client::Errors::ClientError && @error_object.status == '403') ||
      #       (@error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status == '401')
      #   custom_error = { 'messages' => [{ 'key' => 'Client error', 'detail' => 'client exception', status: '400' }] }
      #   update_claim(custom_error)
      #   log_outcome_for_claims_api(custom_error)

      #   raise EVSS::DisabilityCompensationForm::ServiceException, custom_error

      else
        custom_error = { 'messages' => [{ 'key' => 'Unknown error', 'detail' => 'unknown error', status: '500' }] }
        update_claim(custom_error)
        log_outcome_for_claims_api(custom_error)

        raise custom_error
      end
    end

    def update_claim(custom_error)
      @claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      @claim.evss_response = custom_error['message']
      # @claim.form_data = @claim.form_data
      @claim.save
    end

    def log_outcome_for_claims_api(custom_error)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "claims_api-526-#{@method},  custom_error: #{custom_error}", claim: @claim&.id)
    end
  end
end
