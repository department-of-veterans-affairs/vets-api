# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'common/models/base'

module Search
  class ResultsResponse < Common::Base
    include Common::Client::ServiceStatus

    attribute :status, Integer
    attribute :body, Hash

    def initialize(status, attributes = nil)
      super(attributes) if attributes
      self.status = status
    end

    def self.from(response)
      body = response.body
      new(response.status, body: body)
    end

    def cache?
      status == 200
    end

    def metadata
      { status: response_status }
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
