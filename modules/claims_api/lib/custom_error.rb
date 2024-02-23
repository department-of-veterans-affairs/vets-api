# frozen_string_literal: true

module ClaimsApi
  class CustomError
    def initialize(error)
      @error = error
    end

    def build_error
      # re-try: bad req build to_internal without curly brace; 401; 403
      # try to raise 401 & 403, see what erorr is returned and work that into this case statement
      if @error == Faraday::ConnectionFailed || @error == Faraday::ParsingError
        error = { 'messages' => [{ 'key' => 'ServiceException', 'detail' => 'test detail', status: '500' }] }
        log_outcome_for_claims_api("claims_api-526-#{method}", 'error', error, claim)

        raise EVSS::DisabilityCompensationForm::ServiceException, error
      # when @error.is_a?(Faraday::ParsingError)
      #     @error_object['detailed_message'] = 'Faraday parsing error'
      #     @error_object['messages'] = { 'key' => 'default' }
      #    when @error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status == '503'
      #         @error_object['detailed_message'] = 'Service unavailable'
      #         @error_object['messages'] = { 'key' => 'ServiceException'}
      #     when @error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status != '403'
      #         @error_object['detailed_message'] = 'Service error'
      #         @error_object['messages'] = { 'key' => 'serviceError'}
      # when @error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status == '403' ||
      #     @error.is_a?(::Common::Client::Errors::ClientError) && @error_object.status == '401'
      #     @error_object['detailed_message'] = 'Service error'
      #     @error_object['messages'] = { 'key' => 'veteran'}
      elsif @error.is_a?(StandardError)
        @error_object['messages'] = { 'key' => 'default' }
        @error_object['detailed_message'] = 'our custom message'
      else
        error = { 'messages' => [{ 'key' => 'ServiceException', 'detail' => 'test detail', status: '500' }] }
        log_outcome_for_claims_api("claims_api-526-#{method}", 'error', error, claim)

        raise error
      end
    end
  end
end
