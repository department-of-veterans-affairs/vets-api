# frozen_string_literal: true

# Transforms a schema from `spec/support/schemas` into one with camelized keys like when
#  OliveBranch is used with the X-Key-Inflection header for `camel`
class SchemaCamelizer
  attr_reader :original_path, :camel_schema, :name, :referenced_schemas, :already_camelized

  def initialize(schema_path, destination_path = nil)
    @original_path = schema_path
    @camel_path = destination_path
    @name = %r{/([^/]*)\.json$}.match(schema_path)[1]
    raw_schema = File.read(schema_path)
    # OliveBranch only changes keys, but the required key's value is an arrray of keys,
    #  these need to be camelized to match the keys to which they refer
    modified_schema = raw_schema.gsub(/"required": \[(["\w*,? \n]*)\]/) do
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

    @camel_schema = OliveBranch::Transformations.transform(JSON.parse(modified_schema), camelizer)
    @already_camelized = JSON.parse(raw_schema).to_json == @camel_schema.to_json

    # some schemas use "$ref" to include a definition from another file, transform any needed also
    @referenced_schemas = raw_schema.scan(/"\$ref": "(.*)\.json"/).flatten.map do |schema_name|
      reference_schema_path = schema_path.gsub(name, schema_name)
      SchemaCamelizer.new(reference_schema_path)
    end
  end

  # The method for camelizing the schema keys
  #
  # @return [method] the method for camelizing schema keys
  def camelizer
    OliveBranch::Transformations.method(:camelize)
  end

  # Getter for path to which new camel schema will be saved
  # defaults to changing `path/to/schemas` to `path/to/schemas_camelized`
  #
  # @return [string] the path for saving the camel schema
  def camel_path
    @camel_path ||= original_path.gsub('schemas', 'schemas_camelized')
  end

  # Saves the #camel_schema to #camel_path
  # raises an error when original schema is not from a schemas directory
  # also saves a camelized version of any referenced schemas
  #
  # @return [array] files created
  def save!
    raise "expected `#camel_path` (#{camel_path}) to be different from the given path" if original_path == camel_path

    camel_path_directories = camel_path.gsub(%r{[^/]*$}, '')
    FileUtils.mkdir_p(camel_path_directories)

    File.open(camel_path, 'w') do |file|
      file.write(JSON.pretty_generate(camel_schema))
      file.write("\n")
    end

    [camel_path].concat(@referenced_schemas.collect(&:save!).flatten)
  end

  # Checks schema and it's references to see if any of them were already camelized
  #
  # @return [array] list of schema names with no changes
  def unchanged_schemas
    return @unchanged_schemas unless @unchanged_schemas.nil?

    @unchanged_schemas = []
    @unchanged_schemas << name if @already_camelized
    referenced_schemas.each do |referenced_camelizer|
      @unchanged_schemas.concat referenced_camelizer.unchanged_schemas
    end
    @unchanged_schemas
  end
end
