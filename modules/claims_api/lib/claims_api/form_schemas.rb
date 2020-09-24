# frozen_string_literal: true

require 'json_schema/form_schemas'

module ClaimsApi
  class FormSchemas < JsonSchema::FormSchemas
    def base_dir
      Rails.root.join('modules', 'claims_api', Settings.claims_api.schema_dir)
    end
  end
end
