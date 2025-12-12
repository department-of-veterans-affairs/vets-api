#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick Module Analysis Script
# Run from vets-api root: ruby quick_module_analysis.rb

puts "=" * 80
puts "VETS-API MODULE QUICK ANALYSIS"
puts "=" * 80
puts

# Parse routes.rb for mounts
routes_content = File.read('./config/routes.rb')
mounts = {}

routes_content.scan(/mount\s+(\w+(?:::\w+)*)::Engine[^,]+at:\s*['"]([^'"]+)['"]/) do |engine, path|
  mounts[engine] = path
end

# Get all modules
modules = Dir.glob('./modules/*').select { |f| File.directory?(f) }
module_names = modules.map { |m| File.basename(m) }

puts "📊 SUMMARY"
puts "-" * 80
puts "Total modules: #{module_names.length}"
puts "Mounted modules: #{mounts.length}"
puts "Unmounted modules: #{module_names.length - mounts.length}"
puts

# Categorize by mount path
v1_modules = mounts.select { |_k, v| v.start_with?('/v1/') }
root_modules = mounts.reject { |_k, v| v.start_with?('/v1/') }

puts "🗂️  MOUNT PATH CATEGORIES"
puts "-" * 80
puts "Under /v1: #{v1_modules.length}"
v1_modules.each { |engine, path| puts "  • #{path} → #{engine}" }
puts
puts "At root level: #{root_modules.length}"
puts

# Find unmounted modules
unmounted = module_names.reject do |name|
  engine_name = name.split('_').map(&:capitalize).join
  mounts.key?(engine_name) || mounts.key?(engine_name.upcase)
end

if unmounted.any?
  puts "⚠️  UNMOUNTED MODULES (#{unmounted.length})"
  puts "-" * 80
  unmounted.each { |name| puts "  • #{name}" }
  puts
end

# Find modules using Vets::SharedLogging
puts "🔍 SHARED CONCERNS USAGE"
puts "-" * 80
shared_logging_users = []

modules.each do |module_dir|
  module_name = File.basename(module_dir)
  uses_shared_logging = false

  Dir.glob("#{module_dir}/**/*.rb").each do |file|
    if File.read(file).match?(/include\s+Vets::SharedLogging|extend\s+Vets::SharedLogging/)
      uses_shared_logging = true
      break
    end
  end

  shared_logging_users << module_name if uses_shared_logging
end

puts "Modules using Vets::SharedLogging: #{shared_logging_users.length}"
if shared_logging_users.any?
  shared_logging_users.each { |name| puts "  • #{name}" }
end
puts

# Count controllers, services, models per module
puts "📈 MODULE SIZES (Top 10 by controllers)"
puts "-" * 80

module_stats = modules.map do |module_dir|
  name = File.basename(module_dir)
  {
    name: name,
    controllers: Dir.glob("#{module_dir}/app/controllers/**/*_controller.rb").length,
    services: Dir.glob("#{module_dir}/app/services/**/*.rb").length,
    models: Dir.glob("#{module_dir}/app/models/**/*.rb").length,
    specs: Dir.glob("#{module_dir}/spec/**/*_spec.rb").length
  }
end

module_stats.sort_by { |m| -m[:controllers] }.first(10).each do |stats|
  puts "  #{stats[:name].ljust(35)} | Controllers: #{stats[:controllers].to_s.rjust(3)} | Services: #{stats[:services].to_s.rjust(3)} | Models: #{stats[:models].to_s.rjust(3)} | Tests: #{stats[:specs].to_s.rjust(4)}"
end

puts
puts "=" * 80
puts "✓ Analysis complete!"
puts
puts "For detailed mapping, run: ruby generate_module_mapping.rb"
