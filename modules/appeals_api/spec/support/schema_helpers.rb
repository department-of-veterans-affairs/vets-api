# frozen_string_literal: true

module SchemaHelpers
  def read_schema(filename, api_name = 'decision_reviews', schema_version = 'v1')
    JSON.parse(
      Rails.root.join(
        'modules',
        'appeals_api',
        'config',
        'schemas',
        api_name,
        schema_version,
        filename
      ).read
    )
  end

  def schema_ref_resolver
    proc do |uri|
      return uri.path unless uri.path.end_with?('.json')

      parsed_schema = JSON.parse File.read shared_schema_dir(uri.path)
      parsed_schema['properties'].values.first
    end
  end

  def schema_after_property_validation
    proc do |data, property, property_schema, _parent|
      data[property] = 'W' * property_schema['maxLength'] if property_schema['maxLength']
    end
  end

  def override_max_lengths(appeal, schema)
    schema_validator = JSONSchemer.schema(schema,
                                          after_property_validation: schema_after_property_validation,
                                          ref_resolver: schema_ref_resolver)
    schema_validator.valid?(appeal.form_data)
    appeal.form_data
  end

  private

  def shared_schema_dir(file)
    Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, 'shared', 'v0', file)
  end
end
