# frozen_string_literal: true

module Sidekiq
  class Batch
    attr_accessor :description
    attr_reader :bid

    def initialize(bid = nil)
      @bid = bid || SecureRandom.hex(8)
      @callbacks = []
    end

    def status
      nil
    end

    def on(*args)
      @callbacks << args
    end

    def jobs(*)
      yield
    end
  end
end
