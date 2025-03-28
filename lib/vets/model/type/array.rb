# frozen_string_literal: true

require 'vets/model/type/base'
require 'vets/model/type/date_time_string'
require 'vets/model/type/hash'
require 'vets/model/type/http_date'
require 'vets/model/type/iso8601_time'
require 'vets/model/type/object'
require 'vets/model/type/primitive'
require 'vets/model/type/titlecase_string'
require 'vets/model/type/utc_time'

module Vets
  module Model
    module Type
      class Array < Base
        def self.primitive
          ::Array
        end

        def cast(value)
          return nil if value.nil?

          raise TypeError, "#{@name} must be an Array" unless value.is_a?(::Array)

          casted_value = value.map { |item| type.cast(item) }

          unless casted_value.all? { |item| item.is_a?(@klass.try(:primitive) || @klass) }
            raise TypeError, "All elements of #{@name} must be of type #{@klass}"
          end

          casted_value
        end

        def type
          @type ||= if Vets::Model::Type::Primitive::PRIMITIVE_TYPES.include?(@klass.name)
                      Vets::Model::Type::Primitive.new(@name, @klass)
                    elsif @klass.module_parents.include?(Vets::Model::Type)
                      @klass.new(@name, @klass)
                    elsif @klass == ::Hash
                      Vets::Model::Type::Hash.new(@name)
                    else
                      Vets::Model::Type::Object.new(@name, @klass)
                    end
        end
      end
    end
  end
end
