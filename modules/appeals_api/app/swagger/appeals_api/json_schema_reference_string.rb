# frozen_string_literal: true

require_relative './json_schema_definition_name.rb'

module AppealsApi
  class JsonSchemaReferenceString
    def initialize(ref_string)
      @ref_string = ref_string
    end

    def to_swagger
      "#/components/schemas/#{definition_name}"
    end

    def valid?
      ref_string.is_a?(String) &&
      (nodes.length == 2 || nodes.length == 3) &&
        nodes.first == '#' &&
        nodes.second == 'definitions'
    end

    private

    attr_reader :ref_string

    def definition_name
      JsonSchemaDefinitionName.new(nodes.third).to_swagger
    end

    def nodes
      @nodes ||= ref_string.split('/')
    end
  end
end
