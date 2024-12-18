# frozen_string_literal: true

module Vets
  module Type
    class Base
      def initialize(name, klass)
        @name = name
        @klass = klass
      end

      def cast(value)
        raise NotImplementedError, "#{self.class} must implement #cast"
      end
    end
  end
end
