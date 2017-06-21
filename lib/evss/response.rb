# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'common/models/base'

module EVSS
  class Response < Common::Base
    include Common::Client::ServiceStatus

    attribute :status, Integer
    attribute :body, Object

    def initialize(response)
      case response
      when Faraday::Response
        self.status = response.status
        parse_body(response.body)
      else
        self.status = response[:status]
        parse_body(response[:body]) if response[:body]
      end
    end

    def parse_body(body)
      self.body = body
    end

    def ok?
      status == 200
    end

    def metadata
      {
        status: response_status
      }
    end

    def response_status
      case status
      when 200
        RESPONSE_STATUS[:ok]
      when 403
        RESPONSE_STATUS[:not_authorized]
      when 404
        RESPONSE_STATUS[:not_found]
      else
        RESPONSE_STATUS[:server_error]
      end
    end
  end
end
