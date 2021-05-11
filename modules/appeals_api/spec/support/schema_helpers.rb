# frozen_string_literal: true

module SchemaHelpers
  def read_schema(filename, schema_version = 'v1')
    JSON.parse(
      File.read(
        Rails.root.join(
          'modules',
          'appeals_api',
          'config',
          'schemas',
          schema_version,
          filename
        )
      )
    )
  end
end
