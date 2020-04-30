# frozen_string_literal: true

require_relative './json_schema_definition_name.rb'

module AppealsApi
  class JsonSchemaReferenceString
    def initialize(reference_string, prefix: nil)
      @reference_string = reference_string
      @prefix = prefix
      raise ArgumentError, "Bad reference string: #{reference_string.inspect}" unless valid?
    end

    def to_swagger
      "#/components/schemas/#{definition_name}"
    end

    private

    attr_reader :reference_string, :prefix

    def definition_name
      JsonSchemaDefinitionName.new(nodes.third, prefix: prefix).to_swagger
    end

    def nodes
      @nodes ||= reference_string.split('/')
    end

    def valid?
      reference_string.is_a?(String) &&
      (nodes.length == 2 || nodes.length == 3) &&
        nodes.first == '#' &&
        nodes.second == 'definitions'
    end
  end
end
