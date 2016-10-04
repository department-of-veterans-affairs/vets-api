# frozen_string_literal: true
require 'savon'
require_relative 'response'

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
  #  birth_date = Time.new(1980, 1, 1).utc
  #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', birth_date, '555-44-3333').to_xml
  #  response = MVI::Service.find_candidate(message)
  #
  class Service
    extend Savon::Model

    def self.load_wsdl
      @wsdl ||= ERB.new(File.read('config/mvi_schema/IdmWebService_200VGOV.wsdl.erb')).result
    end

    client wsdl: load_wsdl
    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    def self.prpa_in201305_uv02(message)
      response = MVI::Response.new(super(xml: message.to_xml))
      invalid_request_handler('find_candidate', response.body) if response.invalid?
      request_failure_handler('find_candidate', response.body) if response.failure?
      response.to_h
    rescue Savon::SOAPFault => e
      # TODO(AJD): cloud watch metric for error code
      Rails.logger.error "mvi find_candidate soap error code: #{e.http.code} message: #{e.message}"
      raise MVI::SOAPError, e.message
    rescue Savon::HTTPError => e
      # TODO(AJD): cloud watch metric for error code
      Rails.logger.error "mvi find_candidate http error code: #{e.http.code} message: #{e.message}"
      raise MVI::HTTPError, e.message
    rescue SocketError => e
      Rails.logger.error "mvi find_candidate socket error: #{e.message}"
      message = 'mvi requires a vpn connection, or use the mock mvi service as detailed in the project README'
      raise MVI::ServiceError, message
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
