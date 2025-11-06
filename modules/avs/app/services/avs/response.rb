# frozen_string_literal: true

require 'vets/model'

# After Visit Summary Model
module Avs
  class Response
    include Vets::Model

    attribute :body, String
    attribute :status, Integer

    def initialize(body, status)
      @body = body
      @status = status
      super()
    end

    def avs
      V0::AfterVisitSummary.new(body)
    end
  end
end
