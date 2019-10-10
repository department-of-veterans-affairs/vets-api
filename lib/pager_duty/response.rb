# frozen_string_literal: true

require 'common/models/base'

module PagerDuty
  class Response < Common::Base
    include ActiveModel::Validations

    attribute :status, Integer

    def initialize(status, attributes = nil)
      super(attributes) if attributes
      self.status = status
    end

    def ok?
      status == 200
    end

    def cache?
      ok?
    end
  end
end
