# frozen_string_literal: true

require 'vets/model/types'

module Vets
  module Model
    module Attributes
      class Value
        def self.cast(name, klass, value, array: false)
          new(name, klass, array:).setter_value(value)
        end

        def initialize(name, klass, array: false)
          @name = name
          @klass = klass
          @array = array
        end

        def setter_value(value)
          type.cast(value)
        end

        # Acts as a "type factory"
        def type
          @type ||= if @array
                      Vets::Model::Type::Array.new(@name, @klass)
                    elsif Vets::Model::Type::Primitive::PRIMITIVE_TYPES.include?(@klass.name)
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
