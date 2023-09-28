# frozen_string_literal: true

require_relative 'adapter'

module Tracers
  class DatadogAdapter < Adapter
    def self.set_tags(service)
      Datadog::Tracing.active_span&.service = service
    end
  end
end
