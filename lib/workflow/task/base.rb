# frozen_string_literal: true

module Workflow
  module Task
    class Base
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
end
