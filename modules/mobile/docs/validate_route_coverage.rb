#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'date'

# Parse routes.rb to extract all route definitions
def extract_routes_from_file(routes_file)
  routes = []
  content = File.read(routes_file)
  current_namespace = ''
  namespace_stack = []

  content.each_line do |line|
    process_namespace_line(line, namespace_stack)
    current_namespace = namespace_stack.empty? ? '' : "/#{namespace_stack.join('/')}"

    extract_standard_route(line, current_namespace, routes)
    extract_resource_routes(line, current_namespace, routes)
  end

  routes
end

def process_namespace_line(line, namespace_stack)
  if line.match(/^\s*(?:namespace|scope)\s+:(\w+)\s+do/)
    namespace_stack.push(Regexp.last_match(1))
  elsif line.match(/^\s*end\s*$/) && !namespace_stack.empty?
    namespace_stack.pop
  end
end

def extract_standard_route(line, current_namespace, routes)
  return unless line.match(/^\s*(get|post|put|patch|delete)\s+['"]([^'"]+)['"]/)

  method = Regexp.last_match(1).upcase
  path = Regexp.last_match(2)
  normalized_path = path.gsub(/:(\w+)/, '{\1}')

  full_path = if current_namespace.empty?
                normalized_path
              elsif normalized_path.start_with?('/')
                current_namespace + normalized_path
              else
                "#{current_namespace}/#{normalized_path}"
              end
  routes << { method:, path: full_path }
end

def extract_resource_routes(line, current_namespace, routes)
  return unless line.match(/resources\s+:(\w+),\s+only:\s+%i\[([^\]]+)\]/)

  resource = Regexp.last_match(1)
  actions = Regexp.last_match(2).split(/\s+/)

  actions.each { |action| add_resource_route(action, resource, current_namespace, routes) }
end

def add_resource_route(action, resource, namespace, routes)
  case action
  when 'index'
    routes << { method: 'GET', path: "#{namespace}/#{resource}" }
  when 'show'
    routes << { method: 'GET', path: "#{namespace}/#{resource}/{id}" }
  when 'create'
    routes << { method: 'POST', path: "#{namespace}/#{resource}" }
  when 'update'
    routes << { method: 'PUT', path: "#{namespace}/#{resource}/{id}" }
    routes << { method: 'PATCH', path: "#{namespace}/#{resource}/{id}" }
  when 'destroy'
    routes << { method: 'DELETE', path: "#{namespace}/#{resource}/{id}" }
  end
end

# Parse OpenAPI YAML to extract documented paths
def extract_openapi_paths(openapi_file)
  openapi = YAML.safe_load_file(openapi_file, permitted_classes: [Time, Date, Symbol])
  documented = []

  openapi['paths']&.each do |path, methods|
    methods.each_key do |method|
      next if method == 'parameters' # Skip parameter definitions

      documented << { method: method.upcase, path: }
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
  { method: route[:method], path: }
end

# Normalize path parameters for flexible matching
# Converts all path parameters to a generic placeholder so {id}, {cancelId}, etc. all match
def normalize_path_params(path)
  path.gsub(/\{[^}]+\}/, '{param}')
end

# Main validation
def validate_coverage(routes_file, openapi_file)
  routes = extract_routes_from_file(routes_file)
  documented = extract_openapi_paths(openapi_file)

  routes_normalized = routes.map { |r| normalize_route(r) }.uniq
  documented_normalized = documented.map { |d| normalize_route(d) }.uniq

  undocumented = find_undocumented_routes(routes_normalized, documented_normalized)

  report_results(undocumented, routes_normalized, documented_normalized)
end

def find_undocumented_routes(routes, documented)
  routes.reject do |route|
    documented.any? do |doc|
      doc[:method] == route[:method] &&
        normalize_path_params(doc[:path]) == normalize_path_params(route[:path])
    end
  end
end

def report_results(undocumented, routes, documented)
  if undocumented.empty?
    puts '✅ All routes are documented in OpenAPI spec!'
    puts "   Total routes: #{routes.size}"
    puts "   Documented: #{documented.size}"
    exit 0
  else
    print_undocumented_routes(undocumented, routes, documented)
    exit 1
  end
end

def print_undocumented_routes(undocumented, routes, documented)
  puts "❌ Found #{undocumented.size} undocumented routes:"
  puts
  undocumented.sort_by { |r| [r[:path], r[:method]] }.each do |route|
    puts "  #{route[:method].ljust(6)} #{route[:path]}"
  end
  puts
  puts "Total routes: #{routes.size}"
  puts "Documented: #{documented.size}"
  puts "Missing: #{undocumented.size}"
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
