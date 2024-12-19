# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class Primitive < Base
      PRIMITIVE_TYPES = [String, Integer, Float, Date, Time, DateTime, Bool].freeze

      def cast(value)
        return value if value.is_a?(@klass) || value.nil?

        begin
          case @klass.name
          when 'DateTime' then DateTime.parse(value.to_s)
          when 'Date' then Date.parse(value.to_s)
          when 'Integer' then Integer(value)
          when 'Float' then Float(value)
          when 'Bool' then ActiveModel::Type::Boolean.new.cast(value)
          else invalid_type!
          end
        rescue
          invalid_type!
        end
      end

      private

      def invalid_type!
        raise TypeError, "#{@name} could not be coerced to #{@klass}"
      end
    end
  end
end
