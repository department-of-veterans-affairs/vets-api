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

  def override_max_lengths(appeal, schema)
    JSONSchemer.schema(schema,
                       after_property_validation: proc do |data, property, property_schema, _parent|
                         data[property] = 'W' * property_schema['maxLength'] if property_schema['maxLength']
                       end).valid?(appeal.form_data)
    appeal.form_data
  end
end
