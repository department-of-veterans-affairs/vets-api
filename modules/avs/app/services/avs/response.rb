# frozen_string_literal: true

require 'common/models/base'

# After Visit Summary Model
module Avs
  class Response < Common::Base
    attribute :body, String
    attribute :status, Integer

    def initialize(body, status)
      super()
      self.body = body
      self.status = status
    end

    def avs
      V0::AfterVisitSummary.new(body)
    end
  end
end
