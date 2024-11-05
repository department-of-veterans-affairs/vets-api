# frozen_string_literal: true

require 'vets/attributes'

# This will be moved after virtus is removed
module Bool; end
class TrueClass; include Bool; end
class FalseClass; include Bool; end

module Vets
  class Model
    extend ActiveModel::Naming
    include ActiveModel::Model
    include ActiveModel::Serializers::JSON
    include Vets::Attributes

    def initialize(params = {})
      # Remove attributes that aren't defined in the class aka unknown
      params.select! { |x| self.class.attribute_set.index(x.to_sym) }

      super
      # Ensure all attributes have a defined value (default to nil)
      self.class.attribute_set.each do |attr_name|
        instance_variable_set("@#{attr_name}", nil) unless instance_variable_defined?("@#{attr_name}")
      end
    end

    # Acts as ActiveRecord::Base#attributes which is needed for serialization
    def attributes
      nested_attributes(instance_values)
    end

    private

    # Collect values from attribute and nested objects
    #
    # @param values [Hash]
    #
    # @return [Hash] nested attributes
    def nested_attributes(values)
      values.transform_values do |value|
        if value.respond_to?(:attributes)
          nested_attributes(value.instance_values)
        else
          value
        end
      end
    end
  end
end
