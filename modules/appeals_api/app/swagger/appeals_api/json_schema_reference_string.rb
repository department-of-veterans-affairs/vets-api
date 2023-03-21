# frozen_string_literal: true

module AppealsApi
  class JsonSchemaReferenceString
    JSON_SCHEMA_DEF_PATH_WITH_TRAILING_SLASH_LENGTH = (
      JSON_SCHEMA_DEF_PATH_WITH_TRAILING_SLASH = "#{JSON_SCHEMA_DEF_PATH = '#/definitions'}/".freeze
    ).length

    SWAGGER_DEF_PATH = '#/components/schemas'

    def initialize(ref)
      @ref_string = (@ref = ref).to_s
    end

    def to_swagger
      raise ArgumentError, "Invalid reference: #{ref.inspect}" unless valid?

      return "#{SWAGGER_DEF_PATH}/#{definition_name}" if definition_name

      SWAGGER_DEF_PATH
    end

    def valid?
      json_schema_definition_path_exactly? ||
        json_schema_definition_path_followed_by_a_string_without_slashes?
    end

    private

    attr_reader :ref, :ref_string

    def json_schema_definition_path_exactly?
      ref_string == JSON_SCHEMA_DEF_PATH
    end

    def json_schema_definition_path_followed_by_a_string_without_slashes?
      ref_string.start_with?(JSON_SCHEMA_DEF_PATH_WITH_TRAILING_SLASH) &&
        definition_name.exclude?('/')
    end

    def definition_name
      ref_string[JSON_SCHEMA_DEF_PATH_WITH_TRAILING_SLASH_LENGTH..]
    end
  end
end
