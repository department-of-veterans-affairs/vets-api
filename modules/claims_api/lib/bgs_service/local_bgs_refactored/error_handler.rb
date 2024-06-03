# frozen_string_literal: true

module ClaimsApi
  class LocalBGSRefactored
    # list of fault codes: https://hub.verj.io/ebase/doc/SOAP_Faults.htm
    class ErrorHandler
      class << self
        def handle_errors!(fault)
          new(fault).handle_errors!
        end
      end

      def initialize(fault)
        @fault = fault
      end

      def handle_errors!
        return if not_error?

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

      private

      def not_error?
        @fault.message.include?('IntentToFileWebService') &&
          @fault.message.include?('not found')
      end

      def not_found?
        errors = ['bnftClaimId-->bnftClaimId/text()', 'not found', 'No Person found']
        has_errors = errors.any? { |error| @fault.message.include? error }
        soap_logging('404') if has_errors
        has_errors
      end

      def bnft_claim_not_found?
        errors = ['No BnftClaim found']
        has_errors = errors.any? { |error| @fault.message.include? error }
        soap_logging('404') if has_errors
        has_errors
      end

      def unprocessable?
        errors = ['java.sql', 'MessageException', 'Validation errors', 'Exception Description',
                  'does not have necessary info', 'Error committing transaction', 'Transaction Rolledback',
                  'Unexpected error', 'XML reader error', 'could not be converted']
        has_errors = errors.any? { |error| @fault.message.include? error }
        soap_logging('422') if has_errors
        has_errors
      end

      def soap_logging(status_code)
        ClaimsApi::Logger.log('soap_error_handler',
                              detail: "Returning #{status_code} via local_bgs & soap_error_handler, " \
                                      "fault_string: #{@fault.message}, with message: #{@fault.message}, " \
                                      "and fault_code: #{@fault.code}.")
      end
    end
  end
end
