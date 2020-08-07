# frozen_string_literal: true

require_relative 'support/schema_camelizer'

namespace :camelize_file do
  desc 'Given a json schema file it is transformed into a camelCase version'
  # example `bundle exec rake camelize_file:schema[user_loa3]`
  task :schema, [:json_schema_file] => [:environment] do |_, args|
    raise IOError, 'No json-schema file provided' unless args[:json_schema_file]

    schema_path = Rails.root.join('spec', 'support', 'schemas', "#{args[:json_schema_file]}.json")
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path

    transformer = SchemaCamelizer.new(schema_path.to_s)
    saved_schemas = transformer.save!
    if saved_schemas.count == 1
      print "Saved camelized schema to #{saved_schemas.first}\n"
    else
      print "Saved camelized schema and its references:\n"
      saved_schemas.each do |save_path|
        print " - #{save_path}\n"
      end
    end
    if transformer.unchanged_schemas.any?
      print "These schemas were already camelized (or perhaps have only one word keys?):\n"
      print "  [#{transformer.unchanged_schemas.join(', ')}]\n"
    end
  end

  task :response, [:response_schema_path] => [:environment] do |_, args|
    raise IOError, 'No json-schema response file provided' unless args[:response_schema_path]

    schema_path = args[:response_schema_path]
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path

    camel_destination = schema_path.gsub('.json', '_in_camel.json')

    transformer = SchemaCamelizer.new(schema_path, camel_destination)
    saved_schemas = transformer.save!
    if saved_schemas.count == 1
      print "Saved camelized responses to #{saved_schemas.first}\n"
    else
      print "Saved camelized responses and its references:\n"
      saved_schemas.each do |save_path|
        print " - #{save_path}\n"
      end
    end
    if transformer.unchanged_schemas.any?
      print "These responses were already camelized (or perhaps have only one word keys?):\n"
      print "  [#{transformer.unchanged_schemas.join(', ')}]\n"
    end
  end
end
