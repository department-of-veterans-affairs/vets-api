#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

# Parse routes.rb to extract all route definitions
def extract_routes_from_file(routes_file)
  routes = []
  content = File.read(routes_file)
  current_namespace = ''
  namespace_stack = []
  
  content.each_line do |line|
    # Track namespace blocks
    if line.match(/^\s*namespace\s+:(\w+)\s+do/)
      namespace_name = $1
      namespace_stack.push(namespace_name)
      current_namespace = '/' + namespace_stack.join('/')
    elsif line.match(/^\s*scope\s+:(\w+)\s+do/)
      # Handle scope blocks similar to namespace
      scope_name = $1
      namespace_stack.push(scope_name)
      current_namespace = '/' + namespace_stack.join('/')
    elsif line.match(/^\s*end\s*$/) && !namespace_stack.empty?
      # Pop namespace on 'end' - this is imperfect but works for most cases
      namespace_stack.pop
      current_namespace = namespace_stack.empty? ? '' : '/' + namespace_stack.join('/')
    end
    
    # Match standard route definitions
    if line.match(/^\s*(get|post|put|patch|delete)\s+['"]([^'"]+)['"]/)
      method = $1.upcase
      path = $2
      # Normalize path - convert Rails params to OpenAPI style
      normalized_path = path.gsub(/:(\w+)/, '{\1}')
      # Build full path with proper separator
      full_path = if current_namespace.empty?
                    normalized_path
                  elsif normalized_path.start_with?('/')
                    current_namespace + normalized_path
                  else
                    "#{current_namespace}/#{normalized_path}"
                  end
      routes << { method: method, path: full_path }
    end
    
    # Handle resources declarations
    if line.match(/resources\s+:(\w+),\s+only:\s+%i\[([^\]]+)\]/)
      resource = $1
      actions = $2.split(/\s+/)
      
      actions.each do |action|
        case action
        when 'index'
          routes << { method: 'GET', path: "#{current_namespace}/#{resource}" }
        when 'show'
          routes << { method: 'GET', path: "#{current_namespace}/#{resource}/{id}" }
        when 'create'
          routes << { method: 'POST', path: "#{current_namespace}/#{resource}" }
        when 'update'
          routes << { method: 'PUT', path: "#{current_namespace}/#{resource}/{id}" }
          routes << { method: 'PATCH', path: "#{current_namespace}/#{resource}/{id}" }
        when 'destroy'
          routes << { method: 'DELETE', path: "#{current_namespace}/#{resource}/{id}" }
        end
      end
    end
  end
  
  routes
end

# Parse OpenAPI YAML to extract documented paths
def extract_openapi_paths(openapi_file)
  openapi = YAML.safe_load_file(openapi_file, permitted_classes: [Time, Date, Symbol])
  documented = []
  
  openapi['paths']&.each do |path, methods|
    methods.each do |method, _spec|
      next if method == 'parameters' # Skip parameter definitions
      documented << { method: method.upcase, path: path }
    end
  end
  
  documented
end

# Normalize route for comparison
def normalize_route(route)
  path = route[:path]
  # Remove trailing slashes
  path = path.sub(%r{/$}, '')
  # Ensure leading slash
  path = "/#{path}" unless path.start_with?('/')
  { method: route[:method], path: path }
end

# Main validation
def validate_coverage(routes_file, openapi_file)
  routes = extract_routes_from_file(routes_file)
  documented = extract_openapi_paths(openapi_file)
  
  # Normalize both sets
  routes_normalized = routes.map { |r| normalize_route(r) }.uniq
  documented_normalized = documented.map { |d| normalize_route(d) }.uniq
  
  # Find undocumented routes
  undocumented = routes_normalized.reject do |route|
    documented_normalized.any? do |doc|
      doc[:method] == route[:method] && doc[:path] == route[:path]
    end
  end
  
  if undocumented.empty?
    puts "✅ All routes are documented in OpenAPI spec!"
    puts "   Total routes: #{routes_normalized.size}"
    puts "   Documented: #{documented_normalized.size}"
    exit 0
  else
    puts "❌ Found #{undocumented.size} undocumented routes:"
    puts
    undocumented.sort_by { |r| [r[:path], r[:method]] }.each do |route|
      puts "  #{route[:method].ljust(6)} #{route[:path]}"
    end
    puts
    puts "Total routes: #{routes_normalized.size}"
    puts "Documented: #{documented_normalized.size}"
    puts "Missing: #{undocumented.size}"
    exit 1
  end
end

# Run validation
if ARGV.length != 2
  puts "Usage: #{$PROGRAM_NAME} <routes.rb> <openapi.yaml>"
  exit 1
end

routes_file = ARGV[0]
openapi_file = ARGV[1]

unless File.exist?(routes_file)
  puts "Error: Routes file not found: #{routes_file}"
  exit 1
end

unless File.exist?(openapi_file)
  puts "Error: OpenAPI file not found: #{openapi_file}"
  exit 1
end

validate_coverage(routes_file, openapi_file)
