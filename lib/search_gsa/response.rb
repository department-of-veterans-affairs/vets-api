# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'common/models/base'
require 'search/pagination'

module SearchGsa
  class ResultsResponse < Common::Base
    include Common::Client::Concerns::ServiceStatus

    attribute :status, Integer
    attribute :body, Hash
    attribute :pagination, SearchGsa::Pagination

    def initialize(status, pagination, attributes = nil)
      super(attributes) if attributes
      self.pagination = pagination
      self.status = status
    end

    def self.from(response)
      pagination = pagination_object(response.body)
      new(response.status, pagination, body: response.body)
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

    def self.pagination_object(body)
      SearchGsa::Pagination.new(body).object
    end
  end
end
