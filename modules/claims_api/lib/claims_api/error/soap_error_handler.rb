# frozen_string_literal: true

require 'nokogiri'

module ClaimsApi
  class SoapErrorHandler
    # list of fault codes: https://hub.verj.io/ebase/doc/SOAP_Faults.htm

    def handle_errors(response)
      @hash = Hash.from_xml(response.body)

      return if @hash&.dig('Envelope', 'Body', 'Fault').blank?

      get_fault_info
    end

    def get_fault_info
      @fault_code = @hash&.dig('Envelope', 'Body', 'Fault', 'faultcode')&.split(':')&.dig(1)
      @fault_string = @hash&.dig('Envelope', 'Body', 'Fault', 'faultstring')
      @fault_message = @hash&.dig('Envelope', 'Body', 'Fault', 'detail', 'MessageException')
      return {} if @fault_string.include?('IntentToFileWebService') && @fault_string.include?('not found')

      get_exception
    end

    private

    def get_exception
      if not_found?
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found.')
      elsif bnft_claim_not_found?
        {}
      elsif unprocessable?
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: 'Please try again after checking your input values.'
        )
      else
        soap_logging('500')
        raise ::Common::Exceptions::ServiceError.new(detail: 'An external server is experiencing difficulty.')
      end
    end

    def not_found?
      errors = ['bnftClaimId-->bnftClaimId/text()', 'not found', 'No Person found']
      has_errors = errors.any? { |error| @fault_string.include? error }
      soap_logging('404') if has_errors
      has_errors
    end

    def bnft_claim_not_found?
      errors = ['No BnftClaim found']
      has_errors = errors.any? { |error| @fault_string.include? error }
      soap_logging('404') if has_errors
      has_errors
    end

    def unprocessable?
      errors = ['java.sql', 'MessageException', 'Validation errors', 'Exception Description',
                'does not have necessary info', 'Error committing transaction', 'Transaction Rolledback',
                'Unexpected error', 'XML reader error', 'could not be converted']
      has_errors = errors.any? { |error| @fault_string.include? error }
      soap_logging('422') if has_errors
      has_errors
    end

    def soap_logging(status_code)
      ClaimsApi::Logger.log('soap_error_handler',
                            detail: "Returning #{status_code} via local_bgs & soap_error_handler, " \
                                    "fault_string: #{@fault_string}, with message: #{@fault_message}, " \
                                    "and fault_code: #{@fault_code}.")
    end
  end
end
