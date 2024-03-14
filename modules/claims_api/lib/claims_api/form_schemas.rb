# frozen_string_literal: true

require 'json_schema/form_schemas'

module ClaimsApi
  class FormSchemas < JsonSchema::FormSchemas
    def initialize(schema_version: 'v1')
      @schema_version = schema_version
      super()
    end

    def base_dir
      Rails.root.join('modules', 'claims_api', Settings.claims_api.schema_dir, @schema_version)
    end
  end
end
