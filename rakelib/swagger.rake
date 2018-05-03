# frozen_string_literal: true

namespace :swagger do
  desc 'Given a json schema file generates a swagger block: `bundle exec rake swagger:generate_block[letters.json]`'
  task :generate_block, [:json_schema_file] => [:environment] do |_, args|
    raise IOError, 'No json-schema file provided' unless args[:json_schema_file]
    schema_path = Rails.root.join('spec', 'support', 'schemas', args[:json_schema_file])
    raise IOError, "No json-schema file at #{schema_path}" unless File.exist? schema_path
    json = JSON.load(schema_path)
    puts "\n-----START BLOCK-----\n\n"
    render_required(json) if json.key?('required')
    render_properties json
    puts "\n-----END BLOCK-----\n"
  end
end

def render_properties(json, indent = 0)
  return unless json.respond_to?(:key?) && json.key?('properties')
  json['properties'].each do |key, value|
    render_property(key, value, indent)
    render_required(value, indent + 1)
    render_properties(value, indent + 1) if value.key?('properties')
    render_items(value, indent + 1) if value.key?('items')
    puts "#{render_indent(indent)}end" if requires_end?(value)
  end
end

def render_property(key, value, indent)
  type = value['type']
  enum = value['enum']
  items = value['items']
  prop = "#{render_indent(indent)}property :#{key}"
  prop += ", type: #{render_type(type, enum)}" unless items
  prop += if requires_end?(value)
            ' do'
          else
            ", example: 'TODO'"
          end
  puts prop
end

def requires_end?(value)
  value.key?('properties') || value.key?('items')
end

def render_items(value, indent = 0)
  items = value['items']
  if items.key? '$ref'
    render_ref(indent)
  else
    render_item(indent, items)
  end
end

def render_ref(indent)
  puts "#{render_indent(indent)}items do"
  puts "#{render_indent(indent)}key :type, :array"
  puts "#{render_indent(indent)}  key :'$ref', 'TODO'"
  puts "#{render_indent(indent)}end"
end

def render_item(indent, items)
  puts "#{render_indent(indent)}items do"
  render_properties(items, indent + 1)
  puts "#{render_indent(indent)}end"
end

def render_required(value, indent = 0)
  puts "#{render_indent(indent)}key :required, #{value['required'].map(&:to_sym)}" if value['required']
end

def render_type(type, enum)
  type = [*type].map(&:to_sym)
  type = [:object] if type == %i[object null] # [object, null] is valid json-schema but swagger throws error
  return type if type.count > 1
  if enum
    ":string, enum: %w(#{enum.map { |x| x }.join(' ')})"
  else
    ":#{type.first}"
  end
end

def render_indent(indent)
  Array.new(indent).map { '  ' }.join('')
end
