# frozen_string_literal: true

require 'vets/model'

module PagerDuty
  class Response
    include Vets::Model

    attribute :status, Integer

    def initialize(status, attributes = nil)
      super(attributes) if attributes
      @status = status
    end

    def ok?
      status == 200
    end

    def cache?
      ok?
    end
  end
end
