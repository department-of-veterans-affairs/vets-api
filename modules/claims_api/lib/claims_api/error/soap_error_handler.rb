# frozen_string_literal: true

require 'nokogiri'

module ClaimsApi
  class SoapErrorHandler
    # list of fault codes: https://hub.verj.io/ebase/doc/SOAP_Faults.htm
    # list faraday errors: https://lostisland.github.io/faraday/middleware/raise-error

    def handle_errors(response)
      hash = Hash.from_xml(response.body)

      return if hash&.dig('Envelope', 'Body', 'Fault').blank?

      fault_description = get_fault_description(hash)

      get_exception(fault_description)
    end

    def get_fault(hash)
      fault_code = hash&.dig('Envelope', 'Body', 'Fault', 'faultcode')
      fault_code.split(':')[1]
    end

    def get_fault_description(hash)
      fault_string = hash&.dig('Envelope', 'Body', 'Fault', 'faultstring')
      return {} if fault_string.include?('IntentToFileWebService') && fault_string.include?('not found')

      if fault_string.include?('No BnftClaim found')
        return {}
      elsif fault_string.include?('could not be converted') ||
            fault_string.include?('not found') ||
            fault_string.include?('No Person found')
        return 'not_found'
      end
      return 'unprocessable' if fault_string.include?('does not have necessary info')
    end

    def get_exception(fault_description)
      case fault_description
      when 'not_found'
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'The BGS server did not find the resource.')
      when 'unprocessable'
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: 'Please try again after checking your input values.'
        )
      when {}
        {}
      else
        raise ::Common::Exceptions::ServiceError.new(detail: 'An external server is experiencing difficulty.')
      end
    end
  end
end
