# frozen_string_literal: true

module Vets
  module Model
    module Type
      class Base
        def initialize(name, klass)
          @name = name
          @klass = klass
        end

        def cast(value)
          raise NotImplementedError, "#{self.class} must implement #cast"
        end

        def self.primitive
          raise NotImplementedError, "#{self.class} must implement #primitive"
        end
      end
    end
  end
end
