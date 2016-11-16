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
  #  birth_date = '1980-1-1'
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
      raise MVI::RecordNotFound.new('MVI multiple matches found') if response.multiple_match?
      raise MVI::InvalidRequestError if response.invalid?
      raise MVI::RequestFailureError if response.failure?
      raise MVI::RecordNotFound.new('MVI subject missing from response body') unless response.body
      response.body
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "MVI find_candidate connection failed: #{e.message}"
      raise MVI::ServiceError, 'MVI connection failed'
    rescue Faraday::TimeoutError
      Rails.logger.error 'MVI find_candidate timeout'
      raise MVI::ServiceError, 'MVI timeout error'
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
        conn.options.open_timeout = MVI::Settings::OPEN_TIMEOUT
        conn.options.timeout = MVI::Settings::TIMEOUT
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
      unless response.status == 200
        Rails.logger.error response.body
        raise MVI::HTTPError.new('MVI HTTP call failed', response.status)
      end
      response
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
  end
end
