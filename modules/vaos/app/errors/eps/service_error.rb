# frozen_string_literal: true

module Eps
  class ServiceError < StandardError
    def initialize(msg = 'An error occurred in the Eps service')
      super
    end
  end
end
