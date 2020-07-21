# frozen_string_literal: true

# Transforms a schema from `spec/support/schemas` into one with camelized keys like when
#  OliveBranch is used with the X-Key-Inflection header for `camel`
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

  # The method for camelizing the schema keys
  #
  # @return [method] the method for camelizing schema keys
  def camelizer
    OliveBranch::Transformations.method(:camelize)
  end

  # Getter for path to which new camel schema will be saved
  #
  # @return [string] the path for saving the camel schema
  def camel_path
    @camel_path ||= original_path.gsub('schemas', 'schemas_camelized')
  end

  # Saves the #camel_schema to #camel_path
  # raises an error when original schema is not from spec/support/schemas
  #
  # @return not used
  def save!
    raise 'expected spec/support/schemas to be original path!' if original_path == camel_path

    File.open(camel_path, 'w') { |file| file.write(camel_schema.to_json) }
  end
end
