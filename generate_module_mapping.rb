#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'

# Script to generate a comprehensive mapping of vets-api modules
# Run from the vets-api root directory: ruby generate_module_mapping.rb

class ModuleMapper
  MODULES_DIR = './modules'

  def initialize
    @mapping = {
      generated_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      summary: {},
      modules: {}
    }
  end

  def generate
    puts "Generating vets-api module mapping..."

    module_dirs.each do |module_dir|
      module_name = File.basename(module_dir)
      puts "  Processing: #{module_name}"

      @mapping[:modules][module_name] = analyze_module(module_dir, module_name)
    end

    generate_summary
    @mapping
  end

  def save_to_file(filename = 'vets_api_module_mapping.json')
    File.write(filename, JSON.pretty_generate(@mapping))
    puts "\n✓ Mapping saved to #{filename}"
  end

  def save_markdown(filename = 'vets_api_module_mapping.md')
    markdown = generate_markdown
    File.write(filename, markdown)
    puts "✓ Markdown report saved to #{filename}"
  end

  private

  def module_dirs
    Dir.glob("#{MODULES_DIR}/*").select { |f| File.directory?(f) }.sort
  end

  def analyze_module(module_dir, module_name)
    {
      path: module_dir,
      has_gemfile: File.exist?(File.join(module_dir, 'Gemfile')),
      has_engine: File.exist?(File.join(module_dir, 'lib', module_name, 'engine.rb')),
      mount_path: extract_mount_path(module_name),
      controllers: find_controllers(module_dir),
      services: find_services(module_dir),
      models: find_models(module_dir),
      routes: find_routes(module_dir),
      specs: count_specs(module_dir),
      concerns_used: find_shared_concerns(module_dir),
      readme_exists: File.exist?(File.join(module_dir, 'README.md')),
      dependencies: extract_gemfile_dependencies(module_dir)
    }
  end

  def extract_mount_path(module_name)
    routes_file = './config/routes.rb'
    return nil unless File.exist?(routes_file)

    content = File.read(routes_file)

    # Convert module_name to the expected Engine class name
    # e.g., "simple_forms_api" -> "SimpleFormsApi::Engine"
    engine_class = module_name.split('_').map(&:capitalize).join

    # Look for mount statements
    mount_line = content.lines.find do |line|
      line.include?("mount #{engine_class}::Engine") ||
      line.include?("mount #{engine_class.upcase}::Engine") # for acronyms like VAOS, SOB
    end

    if mount_line && mount_line =~ /at:\s*['"]([^'"]+)['"]/
      $1
    else
      nil
    end
  end

  def find_controllers(module_dir)
    controller_files = Dir.glob("#{module_dir}/app/controllers/**/*_controller.rb")
    controller_files.map do |file|
      {
        name: File.basename(file, '.rb'),
        path: file.gsub("#{module_dir}/", ''),
        actions: extract_controller_actions(file)
      }
    end
  end

  def extract_controller_actions(file)
    content = File.read(file)
    actions = []

    # Find method definitions (simple regex, won't catch all edge cases)
    content.scan(/^\s*def\s+(\w+)/) do |match|
      action = match[0]
      # Skip common private methods and callbacks
      next if %w[set_tags private protected].include?(action)
      actions << action
    end

    actions
  end

  def find_services(module_dir)
    service_files = Dir.glob("#{module_dir}/app/services/**/*.rb")
    service_files.map do |file|
      {
        name: File.basename(file, '.rb'),
        path: file.gsub("#{module_dir}/", '')
      }
    end
  end

  def find_models(module_dir)
    model_files = Dir.glob("#{module_dir}/app/models/**/*.rb")
    model_files.map do |file|
      {
        name: File.basename(file, '.rb'),
        path: file.gsub("#{module_dir}/", '')
      }
    end
  end

  def find_routes(module_dir)
    routes_file = File.join(module_dir, 'config', 'routes.rb')
    return [] unless File.exist?(routes_file)

    content = File.read(routes_file)
    routes = []

    # Extract route definitions (simplified)
    content.scan(/^\s*(get|post|put|patch|delete|resource|resources)\s+['"]([^'"]+)['"]/) do |method, path|
      routes << "#{method.upcase} #{path}"
    end

    routes
  end

  def count_specs(module_dir)
    spec_files = Dir.glob("#{module_dir}/spec/**/*_spec.rb")
    {
      total: spec_files.length,
      request_specs: Dir.glob("#{module_dir}/spec/requests/**/*_spec.rb").length,
      model_specs: Dir.glob("#{module_dir}/spec/models/**/*_spec.rb").length,
      service_specs: Dir.glob("#{module_dir}/spec/services/**/*_spec.rb").length
    }
  end

  def find_shared_concerns(module_dir)
    concerns = []

    # Search Ruby files for "include Vets::" or "extend Vets::"
    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      content = File.read(file)
      content.scan(/(include|extend)\s+(Vets::\w+)/) do |_type, concern|
        concerns << concern unless concerns.include?(concern)
      end
    end

    concerns.sort
  end

  def extract_gemfile_dependencies(module_dir)
    gemfile = File.join(module_dir, 'Gemfile')
    return [] unless File.exist?(gemfile)

    content = File.read(gemfile)
    deps = []

    # Extract gem declarations
    content.scan(/^\s*gem\s+['"]([^'"]+)['"]/) do |gem_name|
      deps << gem_name[0]
    end

    deps
  end

  def generate_summary
    total_modules = @mapping[:modules].length
    mounted_modules = @mapping[:modules].count { |_k, v| v[:mount_path] }
    modules_with_gemfile = @mapping[:modules].count { |_k, v| v[:has_gemfile] }

    total_controllers = @mapping[:modules].sum { |_k, v| v[:controllers].length }
    total_services = @mapping[:modules].sum { |_k, v| v[:services].length }
    total_models = @mapping[:modules].sum { |_k, v| v[:models].length }
    total_specs = @mapping[:modules].sum { |_k, v| v[:specs][:total] }

    @mapping[:summary] = {
      total_modules: total_modules,
      mounted_modules: mounted_modules,
      unmounted_modules: total_modules - mounted_modules,
      modules_with_gemfile: modules_with_gemfile,
      total_controllers: total_controllers,
      total_services: total_services,
      total_models: total_models,
      total_specs: total_specs,
      unmounted_module_names: @mapping[:modules].select { |_k, v| v[:mount_path].nil? }.keys
    }
  end

  def generate_markdown
    md = []
    md << "# vets-api Module Mapping"
    md << ""
    md << "Generated: #{@mapping[:generated_at]}"
    md << ""
    md << "## Summary"
    md << ""
    md << "| Metric | Count |"
    md << "|--------|-------|"
    @mapping[:summary].each do |key, value|
      next if key == :unmounted_module_names
      md << "| #{key.to_s.split('_').map(&:capitalize).join(' ')} | #{value} |"
    end
    md << ""

    if @mapping[:summary][:unmounted_module_names].any?
      md << "### Unmounted Modules"
      md << ""
      @mapping[:summary][:unmounted_module_names].each do |name|
        md << "- `#{name}`"
      end
      md << ""
    end

    md << "## Module Details"
    md << ""

    @mapping[:modules].sort.each do |module_name, data|
      md << "### #{module_name}"
      md << ""
      md << "**Mount Path:** `#{data[:mount_path] || 'NOT MOUNTED'}`"
      md << ""
      md << "**Has Gemfile:** #{data[:has_gemfile] ? '✓' : '✗'}"
      md << ""

      if data[:controllers].any?
        md << "**Controllers:** #{data[:controllers].length}"
        data[:controllers].each do |controller|
          md << "  - `#{controller[:name]}` (#{controller[:actions].length} actions)"
          if controller[:actions].any?
            md << "    - Actions: #{controller[:actions].join(', ')}"
          end
        end
        md << ""
      end

      if data[:services].any?
        md << "**Services:** #{data[:services].length}"
        data[:services].first(5).each do |service|
          md << "  - `#{service[:name]}`"
        end
        md << "  - ..." if data[:services].length > 5
        md << ""
      end

      if data[:models].any?
        md << "**Models:** #{data[:models].length}"
        data[:models].first(5).each do |model|
          md << "  - `#{model[:name]}`"
        end
        md << "  - ..." if data[:models].length > 5
        md << ""
      end

      if data[:routes].any?
        md << "**Routes:** #{data[:routes].length}"
        data[:routes].first(10).each do |route|
          md << "  - `#{route}`"
        end
        md << "  - ..." if data[:routes].length > 10
        md << ""
      end

      if data[:concerns_used].any?
        md << "**Shared Concerns Used:**"
        data[:concerns_used].each do |concern|
          md << "  - `#{concern}`"
        end
        md << ""
      end

      specs = data[:specs]
      if specs[:total] > 0
        md << "**Tests:** #{specs[:total]} total (#{specs[:request_specs]} request, #{specs[:model_specs]} model, #{specs[:service_specs]} service)"
        md << ""
      end

      if data[:dependencies].any?
        md << "<details>"
        md << "<summary><strong>Gem Dependencies</strong> (#{data[:dependencies].length})</summary>"
        md << ""
        data[:dependencies].each do |dep|
          md << "- #{dep}"
        end
        md << ""
        md << "</details>"
        md << ""
      end

      md << "---"
      md << ""
    end

    md.join("\n")
  end
end

# Run the mapper
if __FILE__ == $0
  mapper = ModuleMapper.new
  mapper.generate
  mapper.save_to_file
  mapper.save_markdown

  puts "\n" + "="*60
  puts "Module Mapping Complete!"
  puts "="*60
  puts "\nFiles generated:"
  puts "  - vets_api_module_mapping.json (detailed JSON data)"
  puts "  - vets_api_module_mapping.md (human-readable report)"
  puts "\nYou can now:"
  puts "  1. Review the markdown file for a quick overview"
  puts "  2. Use the JSON file for programmatic analysis"
  puts "  3. Commit these files to your repo for documentation"
end
