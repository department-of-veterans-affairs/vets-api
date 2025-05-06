# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class Hash < Base
      def initialize(name)
        super(name, ::Hash)
      end

      def self.primitive
        ::Hash
      end

      def cast(value)
        return nil if value.nil?

        raise TypeError, "#{@name} must be a Hash" unless value.is_a?(::Hash)

        value
      end
    end
  end
end
