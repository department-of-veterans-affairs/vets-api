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
  end
end
