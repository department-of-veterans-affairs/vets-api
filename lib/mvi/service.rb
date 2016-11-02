# frozen_string_literal: true
require 'savon'
require 'mvi/settings'
require_relative 'responses/find_candidate'

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
  #  birth_date = Time.new(1980, 1, 1).utc
  #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', birth_date, '555-44-3333').to_xml
  #  response = MVI::Service.new.find_candidate(message)
  #
  class Service
    OPERATIONS = {
      add_person: 'PRPA_IN201301UV02',
      update_person: 'PRPA_IN201302UV02',
      find_candidate: 'PRPA_IN201305UV02'
    }.freeze

    def self.options
      opts = {
        url: MVI::Settings::URL
      }
      if MVI::Settings::SSL_CERT && MVI::Settings::SSL_KEY
        opts[:ssl] = {
          client_cert: MVI::Settings::SSL_CERT,
          client_key: MVI::Settings::SSL_KEY
        }
      end
      opts
    end

    def find_candidate(message)
      faraday_response = call(OPERATIONS[:find_candidate], message.to_xml)
      response = MVI::Responses::FindCandidate.new(faraday_response)
      puts "invalid #{response.invalid?}"
      puts "failure #{response.failure?}"
      invalid_request_handler('find_candidate', response.original_response) if response.invalid?
      request_failure_handler('find_candidate', response.original_response) if response.failure?
      raise MVI::RecordNotFound.new('MVI subject missing from response body', response) unless response.body
      response.body
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "MVI find_candidate connection failed: #{e.message}"
      raise MVI::ServiceError, 'MVI connection failed'
    end

    def self.breakers_service
      path = URI.parse(options[:url]).path
      host = URI.parse(options[:url]).host
      matcher = proc do |request_env|
        request_env.url.host == host && request_env.url.path =~ /^#{path}/
      end

      @service = Breakers::Service.new(
        name: 'MVI',
        request_matcher: matcher
      )
    end

    private

    def connection
      @conn ||= Faraday.new(MVI::Service.options) do |conn|
        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end

    def call(operation, body)
      response = connection.post '' do |request|
        request.headers['Date'] = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
        request.headers['Content-Length'] = body.bytesize.to_s
        request.headers['Content-Type'] = 'text/xml;charset=UTF-8'
        request.headers['SOAPAction'] = operation
        request.body = body
      end
      puts response.inspect
      unless response.status == 200
        Rails.logger.error response.body
        raise MVI::HTTPError.new('MVI HTTP call failed', response.status)
      end
      response
    end

    def invalid_request_handler(operation, xml)
      puts "B"
      Rails.logger.error "mvi #{operation} invalid request structure: #{xml}"
      raise MVI::InvalidRequestError
    end

    def request_failure_handler(operation, xml)
      puts "C"
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
    attr_accessor :code

    def initialize(message = nil, code = nil)
      super(message)
      @code = code
    end
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
