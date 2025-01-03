# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class Object < Base
      def cast(value)
        return nil if value.nil?

        if value.is_a?(::Hash)
          @klass.new(value)
        elsif value.is_a?(@klass)
          value
        else
          raise TypeError, "#{@name} must be a Hash or an instance of #{@klass}"
        end
      end
    end
  end
end
