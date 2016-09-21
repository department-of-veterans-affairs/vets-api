# frozen_string_literal: true
require 'savon'

module MVI
  # Wrapper for the MVI (Master Veteran Index) Service. vets.gov has access
  # to three MVI endpoints:
  # * prpa_in201301_uv02 (TODO(AJD): Add Person)
  # * prpa_in201302_uv02 (TODO(AJD): Update Person)
  # * prpa_in201305_uv02 (aliased as .find_candidate)
  #
  # = Usage
  # Calls endpoints as class methods, if successful it will return a ruby hash of the SOAP XML response.
  #
  # Example:
  #  dob = Time.new(1980, 1, 1).utc
  #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', dob, '555-44-3333').to_xml
  #  response = MVI::Service.find_candidate(message)
  #
  class Service
    extend Savon::Model

    RESPONSE_CODES = {
      success: 'AA',
      failure: 'AE',
      invalid_request: 'AR'
    }.freeze

    def self.load_wsdl
      @wsdl ||= ERB.new("#{Rails.root}/config/mvi_schema/IdmWebService_200VGOV.wsdl.erb").result
    end

    client wsdl: load_wsdl
    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    def self.prpa_in201305_uv02(message)
      response = super(xml: message)
      body = response.body[:prpa_in201306_uv02]
      code = body[:acknowledgement][:type_code][:@code]
      invalid_request_handler('find_candidate', body) if code == RESPONSE_CODES[:invalid_request]
      request_failure_handler('find_candidate', body) if code == RESPONSE_CODES[:failure]
      return formatted_response(body)
    rescue Savon::SOAPFault => e
      # TODO(AJD): cloud watch metric for error code
      Rails.logger.error "mvi find_candidate soap error code: #{e.http.code} message: #{e.message}"
      raise MVI::SOAPError, e.message
    rescue Savon::HTTPError => e
      # TODO(AJD): cloud watch metric for error code
      Rails.logger.error "mvi find_candidate http error code: #{e.http.code} message: #{e.message}"
      raise MVI::HTTPError, e.message
    end

    singleton_class.send(:alias_method, :find_candidate, :prpa_in201305_uv02)

    def self.invalid_request_handler(operation, body)
      Rails.logger.error "mvi #{operation} invalid request structure: #{body}"
      raise MVI::InvalidRequestError
    end

    def self.request_failure_handler(operation, body)
      Rails.logger.error "mvi #{operation} request failure: #{body}"
      raise MVI::RequestFailureError
    end

    def self.formatted_response(body)
      # TODO(AJD): correlation ids should eventually be a hash but need to investigate
      # what all the possible types are
      patient = body[:control_act_process][:subject][:registration_event][:subject1][:patient]
      {
        correlation_ids: patient[:id].map { |id| id[:@extension] },
        status: patient[:status_code][:@code],
        given_names: patient[:patient_person][:name].first[:given].map(&:capitalize),
        family_name: patient[:patient_person][:name].first[:family].capitalize,
        gender: patient[:patient_person][:administrative_gender_code][:@code],
        dob: patient[:patient_person][:birth_time][:@value],
        ssn: patient[:patient_person][:as_other_i_ds][:id][:@extension].gsub(
          /(\d{3})[^\d]?(\d{2})[^\d]?(\d{4})/,
          '\1-\2-\3'
        )
      }
    end
  end
  class ServiceError < StandardError
  end
  class RequestFailureError < MVI::ServiceError
  end
  class InvalidRequestError < MVI::ServiceError
  end
  class SOAPError < MVI::ServiceError
  end
  class HTTPError < MVI::ServiceError
  end
end
