# frozen_string_literal: true

require 'vets/attributes'
require 'vets/model/dirty'

# This will be moved after virtus is removed
module Bool; end
class TrueClass; include Bool; end
class FalseClass; include Bool; end

# This will be a replacement for Common::Base
module Vets
  module Model
    extend ActiveSupport::Concern
    include ActiveModel::Model
    include ActiveModel::Serializers::JSON
    include Vets::Attributes
    include Vets::Model::Dirty

    included do
      extend ActiveModel::Naming
    end

    def initialize(params = {})
      # Remove attributes that aren't defined in the class aka unknown
      params.select! { |x| self.class.attribute_set.index(x.to_sym) }

      super
      # Ensure all attributes have a defined value (default to nil)
      self.class.attribute_set.each do |attr_name|
        instance_variable_set("@#{attr_name}", nil) unless instance_variable_defined?("@#{attr_name}")
      end

      # required for Vets::Model::Dirty
      @original_attributes = attribute_values.dup
    end

    # Acts as ActiveRecord::Base#attributes which is needed for serialization
    def attributes
      nested_attributes(attribute_values)
    end

    # Acts as Object#instance_values
    def attribute_values
      self.class.attribute_set.to_h { |attr| [attr.to_s, send(attr)] }
    end

    private

    # Collect values from attribute and nested objects
    #
    # @param values [Hash]
    #
    # @return [Hash] nested attributes
    def nested_attributes(values)
      values.transform_values do |value|
        if value.respond_to?(:attribute_values)
          nested_attributes(value.attribute_values)
        else
          value
        end
      end
    end
  end
end

module Vets
  module Model
    def initialize(params = {})
      super(params)
      @original_attributes = attribute_values
    end
  end
end
