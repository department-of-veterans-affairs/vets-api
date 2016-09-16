# frozen_string_literal: true
require 'savon'

module MVI
  class Service
    extend Savon::Model

    client wsdl: "#{ENV['MVI_SCHEMA_PATH']}/IdmWebService_200VGOV.wsdl"

    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    RESPONSE_CODES = {
      success: 'AA',
      failure: 'AE',
      invalid_request: 'AR'
    }.freeze

    def self.prpa_in201305_uv02(first_name, last_name, dob, ssn)
      message = MVI::Messages::FindCandidateMessage.build(first_name, last_name, dob, ssn)
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
        first_name: patient[:patient_person][:name].first[:given].capitalize,
        last_name: patient[:patient_person][:name].first[:family].capitalize,
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
