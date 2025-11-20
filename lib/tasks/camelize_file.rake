# frozen_string_literal: true

require_relative 'support/schema_camelizer'

namespace :camelize_file do
  desc 'Given a json schema file in spec/support/schemas, it creates a camelCase version'
  # example `bundle exec rake camelize_file:schema[user_loa3]`
  task :schema, [:json_schema_file] => [:environment] do |_, args|
    raise IOError, 'No json-schema file provided' unless args[:json_schema_file]

    schema_path = Rails.root.join('spec', 'support', 'schemas', "#{args[:json_schema_file]}.json")
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path

    transformer = SchemaCamelizer.new(schema_path.to_s)
    saved_files = transformer.save!
    if saved_files.count == 1
      print "Saved camelized schema to #{saved_files.first}\n"
    else
      print "Saved camelized schema and its references:\n"
      saved_files.each do |save_path|
        print " - #{save_path}\n"
      end
    end
    if transformer.unchanged_schemas.any?
      print "These schemas were already camelized (or perhaps have only one word keys?):\n"
      print "  [#{transformer.unchanged_schemas.join(', ')}]\n"
    end
  end

  desc 'Given a json file it is transformed into a camelCase version'
  # example `bundle exec rake camelize_file:json[spec/support/pagerduty/maintenance_windows_simple.json]`
  task :json, [:json_path] => [:environment] do |_, args|
    json_path = args[:json_path]
    raise IOError, 'No json file provided' unless json_path
    raise IOError, "Expected `#{json_path}` to be a .json file" unless json_path =~ /\.json$/
    raise IOError, "No json file at #{json_path}" unless File.exist? json_path

    camel_destination = json_path.gsub('.json', '_in_camel.json')

    transformer = SchemaCamelizer.new(json_path, camel_destination)
    saved_files = transformer.save!
    if saved_files.count == 1
      print "Saved camelized json to #{saved_files.first}\n"
    else
      print "Saved camelized json and its references:\n"
      saved_files.each do |save_path|
        print " - #{save_path}\n"
      end
    end
    if transformer.unchanged_schemas.any?
      print "These json files were already camelized (or perhaps have only one word keys?):\n"
      print "  [#{transformer.unchanged_schemas.join(', ')}]\n"
    end
  end
end
