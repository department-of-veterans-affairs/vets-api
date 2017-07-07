# frozen_string_literal: true
namespace :swagger do
  desc 'Given a json schema file generates a swagger block'
  task :generate_block, [:json_schema_file] => [:environment] do |_, args|
    raise IOError, 'No json-schema file provided' unless args[:json_schema_file]
    schema_path = Rails.root.join('spec', 'support', 'schemas', args[:json_schema_file])
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path
    json = JSON.load(schema_path)
    puts "\n-----START BLOCK-----\n\n"
    render_properties json
    puts "\n-----END BLOCK-----\n"
  end
end

def render_properties(json, indent = 0)
  return unless json.respond_to?(:key?) && json.key?('properties')
  node = json['properties']
  node.each do |key, value|
    type, enum, items = value['type'], value['enum'], value['items']
    prop = "#{render_indent(indent)}property :#{key}"
    prop += ", type: #{render_type(type, enum)}" unless items
    prop += if value.key?('properties') || items
              ' do'
            else
              ', example: #TODO: add example'
            end
    puts prop
    render_required(value, indent) if value['required']
    render_properties(value, indent + 1) if value.key?('properties')
    render_items(items, indent) if items
    puts "#{render_indent(indent)}end" if value.key?('properties') || items
  end
end

def render_items(items, indent)
  puts "#{render_indent(indent + 1)}key :type, :array"
  puts "#{render_indent(indent + 1)}items do"
  puts "#{render_indent(indent + 1)}  key :'$ref', #TODO: add ref"
  puts "#{render_indent(indent + 1)}end"
end

def render_required(value, indent)
  puts "#{render_indent(indent + 1)}key :required, #{value['required'].map(&:to_sym)}"
end

def render_type(type, enum)
  type = [*type].map(&:to_sym)
  return type if type.count > 1
  if enum
    "string, enum: #{enum}"
  else
    type.first
  end
end

def render_indent(indent)
  Array.new(indent).map { '  ' }.join('')
end
