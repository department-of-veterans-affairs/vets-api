# frozen_string_literal: true

namespace :camelize_file do
  desc 'Given a json schema file generates a swagger block: `bundle exec rake swagger:generate_block[letters.json]`'
  task :schema, [:json_schema_file] => [:environment] do |_, args|
    raise IOError, 'No json-schema file provided' unless args[:json_schema_file]

    schema_path = Rails.root.join('spec', 'support', 'schemas', "#{args[:json_schema_file]}.json")
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path

    transformer = SchemaCamelizer.new(schema_path.to_s)
    transformer.save!
    print "Saved camelized schema to #{transformer.camel_path}\n"
  end
end

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
