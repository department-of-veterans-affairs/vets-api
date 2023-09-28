# frozen_string_literal: true

module Tracers
  class Adapter
    def self.set_service_tag(service)
      raise NotImplementedError, 'Tracer must implement the `set_service_tag` method'
    end
  end
end
