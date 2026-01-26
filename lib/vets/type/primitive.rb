# frozen_string_literal: true

require 'vets/type/base'

# ActiveModel::Type::String converts booleans to single letter strings.
# Rather than implement the suggested default approach, I think it would be better
# to globally change this to a more expected result like .to_s
# source: https://api.rubyonrails.org/classes/ActiveModel/Type/ImmutableString.html
class BooleanSafeString < ActiveModel::Type::String
  def cast(value)
    case value
    when true  then 'true'
    when false then 'false'
    else
      super
    end
  end
end

ActiveRecord::Type.register(:boolean_safe_string, BooleanSafeString)

module Vets
  module Type
    class Primitive < Base
      PRIMITIVE_TYPES = %w[String Integer Float Date Time DateTime Bool].freeze

      def cast(value)
        return value if value.is_a?(@klass) || value.nil?

        begin
          case @klass.name
          when 'String' then ActiveRecord::Type.lookup(:boolean_safe_string).cast(value)
          when 'Integer' then ActiveModel::Type::Integer.new.cast(value)
          when 'Float' then ActiveModel::Type::Float.new.cast(value)
          when 'Date' then ActiveModel::Type::Date.new.cast(value)
          when 'Time' then Time.zone.parse(value.to_s)
          when 'DateTime' then ActiveModel::Type::DateTime.new.cast(value)
          when 'Bool' then ActiveModel::Type::Boolean.new.cast(value)
          else invalid_type!
          end
        rescue
          invalid_type!
        end
      end

      private

      def invalid_type!
        raise TypeError, "#{@name} could not be casted to #{@klass}"
      end
    end
  end
end
