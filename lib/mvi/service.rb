# frozen_string_literal: true
require 'common/client/base'
require 'mvi/configuration'
require 'mvi/responses/find_candidate'
require 'soap/errors'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'

module MVI
  # Wrapper for the MVI (Master Veteran Index) Service. vets.gov has access
  # to three MVI endpoints:
  # * PRPA_IN201301UV02 (TODO(AJD): Add Person)
  # * PRPA_IN201302UV02 (TODO(AJD): Update Person)
  # * PRPA_IN201305UV02 (aliased as .find_candidate)
  #
  # = Usage
  # Calls endpoints as class methods, if successful it will return a ruby hash of the SOAP XML response.
  #
  # Example:
  #  birth_date = '1980-1-1'
  #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', birth_date, '555-44-3333').to_xml
  #  response = MVI::Service.new.find_candidate(message)
  #
  class Service < Common::Client::Base
    OPERATIONS = {
      add_person: 'PRPA_IN201301UV02',
      update_person: 'PRPA_IN201302UV02',
      find_candidate: 'PRPA_IN201305UV02'
    }.freeze

    configuration MVI::Configuration

    def find_candidate(message)
      raw_response = perform(:post, '', message.to_xml, soapaction: OPERATIONS[:find_candidate])
      response = MVI::Responses::FindCandidate.new(raw_response)
      raise SOAP::Errors::RecordNotFound, 'MVI multiple matches found' if response.multiple_match?
      raise SOAP::Errors::InvalidRequestError if response.invalid?
      raise SOAP::Errors::RequestFailureError if response.failure?
      raise SOAP::Errors::RecordNotFound, 'MVI subject missing from response body' unless response.body
      response.body
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "MVI find_candidate connection failed: #{e.message}"
      raise SOAP::Errors::ServiceError, 'MVI connection failed'
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "MVI find_candidate error: #{e.message}"
      raise SOAP::Errors::ServiceError
    end
  end
end
