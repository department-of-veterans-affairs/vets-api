# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    def base_dir
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir)
    end
  end
end
