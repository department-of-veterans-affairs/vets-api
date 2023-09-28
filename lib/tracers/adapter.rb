# frozen_string_literal: true

module Tracers
  class Adapter
    def self.set_tags(tags)
      raise NotImplementedError, 'Tracer must implement the `set_tags` method'
    end
  end
end
