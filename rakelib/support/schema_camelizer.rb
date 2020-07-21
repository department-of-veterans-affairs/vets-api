# frozen_string_literal: true

class SchemaCamelizer
  attr_reader :original_path, :camel_schema

  def initialize(schema_path)
    @original_path = schema_path
    raw_schema = File.read(schema_path)
    # OliveBranch only changes keys, but the required key's value is an arrray of keys,
    #  these need to be camelized to match the keys to which they refer
    raw_schema.gsub!(/"required": \[(["\w*"\,? ?\n?]*)\]/) do
      # rubocop:disable Style/PerlBackrefs
      # use $1 to refer to the matched part of the gsub, which would be a string of quoted keys
      # split the string into an array of quoted keys
      # strip the whitespace
      # camelize each value without the quotes
      keys = $1.split(',').map(&:strip).map { |key| camelizer.call(key.gsub('"', '')) }
      # rubocop:enable Style/PerlBackrefs
      # rebuild the matched required key-value with quoted and camelized keys in the area
      "\"required\": [#{keys.map { |key| "\"#{key}\"" }.join(', ')}]"
    end
    hashed_schema = JSON.parse(raw_schema)
    @camel_schema = OliveBranch::Transformations.transform(hashed_schema, camelizer)
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
