# frozen_string_literal: true

class SchemaCamelizer
  attr_reader :original_path

  def initialize(schema_path)
    @original_path = schema_path
    raw_schema = File.read(schema_path)
    raw_schema.gsub!(/"required": \[(["\w*"\,? ?\n?]*)\]/) do
      # rubocop:disable Style/PerlBackrefs
      keys = $1.split(',').map(&:strip).map { |key| camelizer.call(key.gsub('"', '')) }
      # rubocop:enable Style/PerlBackrefs
      "\"required\": [#{keys.map { |key| "\"#{key}\"" }.join(', ')}]"
    end
    @camel_schema = JSON.parse(raw_schema)
    @cameled = false
  end

  def camel_schema
    unless @cameled
      OliveBranch::Transformations.transform(@camel_schema, camelizer)
      @cameled = true
    end
    @camel_schema
  end

  def camelizer
    OliveBranch::Transformations.method(:camelize)
  end

  def camel_path
    @camel_path ||= original_path.gsub('schemas', 'schemas_camelized')
  end

  def save!
    raise 'expected spec/support/schemas to be original path!' if original_path == camel_path

    File.open(camel_path, 'w') { |file| file.write(camel_schema.to_json) }
  end
end
