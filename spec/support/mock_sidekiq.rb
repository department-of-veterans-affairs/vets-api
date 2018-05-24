# frozen_string_literal: true

module MockSidekiq
  class Batch
    def on end

    def jobs
      yield
    end
  end
end
