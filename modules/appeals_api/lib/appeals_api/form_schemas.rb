# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    BASE_DIR = Rails.root.join('modules', 'appeals_api', Settings.appeals.schema_dir)

  end
end
