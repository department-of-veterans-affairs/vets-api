# frozen_string_literal: true
module Workflow
  class Task
    attr_accessor :data
    attr_reader :internal

    def initialize(data, internal: {})
      @data = data
      @internal = internal
    end

    def logger
      Sidekiq.logger
    end
  end
end
