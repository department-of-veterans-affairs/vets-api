# frozen_string_literal: true

# Dir['lib/vets/type/**/*.rb'].each { |file| require file.gsub('lib/', '') }

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

      def self.primitive
        raise NotImplementedError, "#{self.class} must implement #primitive"
      end
    end
  end
end
