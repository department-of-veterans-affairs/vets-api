# frozen_string_literal: true
require 'savon'
require_relative 'responses/find_candidate'

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

    def self.options
      opts = {
        url: ENV['MVI_URL']
      }
      if ENV['MVI_CLIENT_CERT_PATH'] && ENV['MVI_CLIENT_KEY_PATH']
        opts.merge!(ssl: {
          client_cert: OpenSSL::X509::Certificate.new(File.read(ENV['MVI_CLIENT_CERT_PATH'])),
          client_key: OpenSSL::PKey::RSA.new(File.read(ENV['MVI_CLIENT_KEY_PATH']))
        })
      end
      opts
    end

    def find_candidate(message)
      response = MVI::Responses::FindCandidate.new(call(message.to_xml))
      invalid_request_handler('find_candidate', response.original_response) if response.invalid?
      request_failure_handler('find_candidate', response.original_response) if response.failure?
      raise MVI::RecordNotFound.new('MVI subject missing from response body', response) unless response.subject
      response.body
    rescue SocketError => e
      Rails.logger.error "mvi find_candidate socket error: #{e.message}"
      message = 'mvi requires a vpn connection, or use the mock mvi service as detailed in the project README'
      raise MVI::ServiceError, message
    end

    private

    def connection
      @conn ||= Faraday.new(MVI::Service.options)
    end

    def call(body)
      response = connection.post '' do |request|
        request.headers['Content-Type'] = 'text/xml;charset=UTF-8'
        request.body = body
      end
      raise MVI::HTTPError unless response.status == 200
      response
    end

    def invalid_request_handler(operation, xml)
      Rails.logger.error "mvi #{operation} invalid request structure: #{xml}"
      raise MVI::InvalidRequestError
    end

    def request_failure_handler(operation, xml)
      Rails.logger.error "mvi #{operation} request failure: #{xml}"
      raise MVI::RequestFailureError
    end
  end
  class ServiceError < StandardError
  end
  class RequestFailureError < MVI::ServiceError
  end
  class InvalidRequestError < MVI::ServiceError
  end
  class HTTPError < MVI::ServiceError
  end
  class RecordNotFound < StandardError
    attr_accessor :query, :original_response
    def initialize(message = nil, response = nil)
      super(message)
      @query = response.query
      @original_response = response.original_response
    end
  end
end
