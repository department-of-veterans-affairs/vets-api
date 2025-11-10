#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'
require 'open3'
require 'optparse'

# Specialized settings sync for upstream connections with exclusion support
# and comment preservation
class UpstreamSettingsSync
  SETTINGS_LOCAL_PATH = File.expand_path('../../config/settings.local.yml', __dir__)

  def initialize
    @options = {}
  end

  def run
    parse_options
    validate_options

    if @options[:exclusions].any?
      puts "Syncing #{@options[:namespace]} settings (excluding #{@options[:exclusions].size} parameters)"
    end

    # Fetch and filter parameters
    parameters = fetch_parameters
    filtered_parameters = filter_parameters(parameters)

    if filtered_parameters.empty?
      puts 'No parameters to sync after applying exclusions'
      return
    end

    # Update settings while preserving comments
    update_settings_preserving_comments(filtered_parameters)

    puts 'Settings sync complete!'
  end

  private

  def parse_options
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: upstream_settings_sync.rb --namespace NAMESPACE --environment ENV [options]'
      opts.separator ''
      opts.separator 'Sync settings from AWS Parameter Store with exclusion support and comment preservation'
      opts.separator ''
      opts.separator 'Options:'

      opts.on('-n', '--namespace NAMESPACE', 'Settings namespace (e.g., lighthouse.letters_generator)') do |namespace|
        @options[:namespace] = namespace
      end

      opts.on('-e', '--environment ENV', 'Environment (e.g., staging, dev, prod)') do |env|
        @options[:environment] = env
      end

      opts.on('--exclude SETTING', 'Exclude a specific setting (can use multiple times)') do |setting|
        @options[:exclusions] ||= []
        @options[:exclusions] << setting
      end

      opts.on('--force', 'Overwrite existing values without prompting') do
        @options[:force] = true
      end

      opts.on('--dry-run', 'Show what would be changed without making changes') do
        @options[:dry_run] = true
      end

      opts.on('--devops-path PATH', 'Path to devops repository (default: ../../../devops)') do |path|
        @options[:devops_path] = path
      end

      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
    end

    parser.parse!
  rescue OptionParser::InvalidOption => e
    puts "Error: #{e.message}"
    puts parser
    exit 1
  end

  def validate_options
    errors = []
    errors << '--namespace is required' unless @options[:namespace]
    errors << '--environment is required' unless @options[:environment]

    if errors.any?
      puts "Error: #{errors.join(', ')}"
      exit 1
    end

    @options[:exclusions] ||= []
    @options[:devops_path] ||= File.expand_path('../../../devops', __dir__)

    # Validate devops path
    unless Dir.exist?(@options[:devops_path])
      puts "Error: devops repository not found at #{@options[:devops_path]}"
      exit 1
    end
  end

  def fetch_parameters
    param_prefix = "/dsva-vagov/vets-api/#{@options[:environment]}/env_vars/#{@options[:namespace].gsub('.', '/')}"
    ssm_script = File.join(@options[:devops_path], 'utilities/ssm-parameters.sh')

    puts "Fetching parameters with prefix: #{param_prefix}"

    if @options[:dry_run]
      puts '[DRY RUN] Would fetch parameters from AWS Parameter Store'
      return { 'sample.param' => 'sample_value' } # Return dummy data for dry run
    end

    cmd = [ssm_script, param_prefix, '--recursive', '--decrypt', '--json']
    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      puts "Error fetching parameters: #{stderr}"
      exit 1
    end

    parse_parameter_response(stdout, param_prefix)
  end

  def parse_parameter_response(stdout, param_prefix)
    response = JSON.parse(stdout)
    parameters = {}

    if response.is_a?(Array)
      response.each do |param|
        if param.is_a?(Hash) && param.key?('Name')
          key_path = param['Name'].sub("#{param_prefix}/", '').split('/')
          parameters[key_path.join('.')] = param['Value']
        end
      end
    elsif response.is_a?(Hash) && response.key?('Parameters')
      response['Parameters'].each do |param|
        key_path = param['Name'].sub("#{param_prefix}/", '').split('/')
        parameters[key_path.join('.')] = param['Value']
      end
    end

    parameters
  rescue JSON::ParserError => e
    puts "Error parsing parameter response: #{e.message}"
    exit 1
  end

  def filter_parameters(parameters)
    original_count = parameters.size
    filtered = parameters.reject { |key, _| @options[:exclusions].include?(key) }
    excluded_count = original_count - filtered.size

    unless @options[:dry_run]
      puts "Found #{original_count} parameters, excluding #{excluded_count}, processing #{filtered.size}"
    end

    @options[:exclusions].each do |excluded|
      puts "  Excluding: #{excluded}" if parameters.key?(excluded) && !@options[:dry_run]
    end

    filtered
  end

  def update_settings_preserving_comments(parameters)
    if File.exist?(SETTINGS_LOCAL_PATH)
      update_existing_file(parameters)
    else
      create_new_file(parameters)
    end
  end

  def update_existing_file(parameters)
    # Process each parameter individually with targeted updates
    parameters.each do |param_name, param_value|
      puts "Processing parameter: #{param_name}" unless @options[:dry_run]

      # Build the full setting path
      keys = param_name.split('.')
      setting_path = @options[:namespace].split('.') + keys

      # Check current value
      current_value = get_current_value(setting_path)

      if should_update_setting?(setting_path.join('.'), current_value, param_value)
        update_single_setting(setting_path, param_value)
      end
    end

    puts "Settings updated in #{SETTINGS_LOCAL_PATH}" unless @options[:dry_run]
  end

  def update_single_setting(setting_path, new_value)
    return if @options[:dry_run]

    # Read the current file content
    lines = File.readlines(SETTINGS_LOCAL_PATH)

    # Find and update the specific line
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    current_indent = 0
    in_namespace = namespace_path.empty?
    namespace_depth = 0
    line_updated = false

    lines.each_with_index do |line, index|
      # Skip comments and empty lines for structure tracking
      next if line.strip.start_with?('#') || line.strip.empty?

      if line.match(/^(\s*)([^:\s#]+):\s*([^#]*)(#.*)?$/)
        line_indent = ::Regexp.last_match(1).length
        key = ::Regexp.last_match(2)
        ::Regexp.last_match(3).strip
        comment = ::Regexp.last_match(4)

        # Navigate namespace hierarchy
        unless in_namespace
          if namespace_depth < namespace_path.length && key == namespace_path[namespace_depth]
            namespace_depth += 1
            current_indent = line_indent
            in_namespace = (namespace_depth == namespace_path.length)
          elsif line_indent <= current_indent && namespace_depth > 0
            namespace_depth = 0
            in_namespace = false
          end
        end

        # Update the target setting
        if in_namespace && key == setting_key
          formatted_value = format_yaml_value(new_value)
          # Preserve any existing comment
          comment_part = comment ? " #{comment}" : ''
          lines[index] = "#{::Regexp.last_match(1)}#{key}: #{formatted_value}#{comment_part}\n"
          line_updated = true
          break
        end
      end
    end

    # If we didn't find the setting, add it (this preserves the original add logic)
    lines = add_new_setting_to_lines(lines, setting_path, new_value) unless line_updated

    # Write back the modified lines
    File.write(SETTINGS_LOCAL_PATH, lines.join)
  end

  def add_new_setting_to_lines(lines, setting_path, new_value)
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    # For new settings, we'll add them in the appropriate namespace
    # This is a simplified version - find the namespace and add at the end
    if namespace_path.empty?
      # Root level setting - add at end
      formatted_value = format_yaml_value(new_value)
      lines << "#{setting_key}: #{formatted_value}\n"
    else
      # Find the namespace and add the setting there
      # For simplicity, add at the end of the file with full namespace structure
      create_namespace_structure_in_lines(lines, namespace_path, setting_key, new_value)
    end

    lines
  end

  def create_namespace_structure_in_lines(lines, namespace_path, key, value)
    # Add the complete namespace structure at the end if it doesn't exist
    indent = 0

    namespace_path.each do |namespace_key|
      lines << "#{'  ' * indent}#{namespace_key}:\n"
      indent += 1
    end

    # Add the final setting
    formatted_value = format_yaml_value(value)
    lines << "#{'  ' * indent}#{key}: #{formatted_value}\n"
  end

  def create_new_file(parameters)
    return if @options[:dry_run]

    # Build settings hash
    settings = {}
    parameters.each do |param_name, param_value|
      keys = param_name.split('.')
      setting_path = @options[:namespace].split('.') + keys
      set_nested_value(settings, setting_path, param_value)
    end

    # Write new file
    FileUtils.mkdir_p(File.dirname(SETTINGS_LOCAL_PATH))
    yaml_content = "---\n#{settings.to_yaml.lines[1..].join}"
    File.write(SETTINGS_LOCAL_PATH, yaml_content)
    puts "Created new settings file: #{SETTINGS_LOCAL_PATH}"
  end

  def get_current_value(setting_path)
    return nil unless File.exist?(SETTINGS_LOCAL_PATH)

    settings = YAML.load_file(SETTINGS_LOCAL_PATH) || {}
    get_nested_value(settings, setting_path)
  rescue Psych::SyntaxError
    nil
  end

  def should_update_setting?(key, current_value, new_value)
    if current_value.nil?
      puts "  Setting new value: #{new_value}" unless @options[:dry_run]
      true
    elsif current_value != new_value
      if @options[:force]
        puts "  Updating value: #{current_value} → #{new_value}" unless @options[:dry_run]
        true
      else
        prompt_for_update(key, current_value, new_value)
      end
    else
      puts '  No change needed (values match)' unless @options[:dry_run]
      false
    end
  end

  def prompt_for_update(key, current_value, new_value)
    return false if @options[:dry_run]

    puts "  Setting '#{key}' already exists:"
    puts "    Current: #{current_value}"
    puts "    New:     #{new_value}"
    print '  Overwrite? [y/N]: '

    response = $stdin.gets&.chomp&.downcase || ''
    update = %w[y yes].include?(response)

    if update
      puts "  Updating value: #{current_value} → #{new_value}"
    else
      puts '  Skipping (keeping existing value)'
    end

    update
  end

  def update_yaml_line(content, setting_path, new_value)
    lines = content.lines
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    # Find and update the existing line
    current_indent = 0
    in_namespace = namespace_path.empty?
    namespace_depth = 0

    lines.each_with_index do |line, index|
      # Skip comments and empty lines for structure tracking
      next if line.strip.start_with?('#') || line.strip.empty?

      if line.match(/^(\s*)([^:\s#]+):\s*([^#]*)(#.*)?$/)
        line_indent = ::Regexp.last_match(1).length
        key = ::Regexp.last_match(2)
        ::Regexp.last_match(3).strip
        comment = ::Regexp.last_match(4)

        # Navigate namespace hierarchy
        unless in_namespace
          if namespace_depth < namespace_path.length && key == namespace_path[namespace_depth]
            namespace_depth += 1
            current_indent = line_indent
            in_namespace = (namespace_depth == namespace_path.length)
          elsif line_indent <= current_indent && namespace_depth > 0
            namespace_depth = 0
            in_namespace = false
          end
        end

        # Update the target setting
        if in_namespace && key == setting_key
          formatted_value = format_yaml_value(new_value)
          # Preserve any existing comment
          comment_part = comment ? " #{comment}" : ''
          lines[index] = "#{::Regexp.last_match(1)}#{key}: #{formatted_value}#{comment_part}\n"
          return lines.join
        end
      end
    end

    # Setting not found, add it
    add_new_setting(lines, setting_path, new_value).join
  end

  def add_new_setting(lines, setting_path, new_value)
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    # Find where to insert the new setting
    if namespace_path.empty?
      # Root level setting
      insert_index = find_root_insertion_point(lines, setting_key)
      formatted_value = format_yaml_value(new_value)
      lines.insert(insert_index, "#{setting_key}: #{formatted_value}\n")
    else
      # Nested setting - find or create namespace
      insert_index = find_namespace_insertion_point(lines, namespace_path)
      if insert_index
        # Add to existing namespace
        indent = calculate_namespace_indent(lines, namespace_path)
        formatted_value = format_yaml_value(new_value)
        lines.insert(insert_index, "#{' ' * indent}#{setting_key}: #{formatted_value}\n")
      else
        # Create new namespace structure
        create_namespace_structure(lines, namespace_path, setting_key, new_value)
      end
    end

    lines
  end

  def find_root_insertion_point(lines, key)
    lines.each_with_index do |line, index|
      next if line.strip.start_with?('#') || line.strip.empty?
      return index if line.match(/^([^:\s]+):/) && ::Regexp.last_match(1) > key
    end
    lines.length
  end

  def find_namespace_insertion_point(_lines, _namespace_path)
    # Implementation for finding where to insert in existing namespace
    # This is complex but handles the YAML structure properly
    # For brevity, using simplified version that creates new namespace
    nil # Will create new namespace
  end

  def calculate_namespace_indent(_lines, namespace_path)
    namespace_path.length * 2
  end

  def create_namespace_structure(lines, namespace_path, key, value)
    indent = 0
    namespace_path.each do |namespace_key|
      lines << "#{'  ' * indent}#{namespace_key}:\n"
      indent += 1
    end

    formatted_value = format_yaml_value(value)
    lines << "#{'  ' * indent}#{key}: #{formatted_value}\n"
  end

  def format_yaml_value(value)
    case value
    when String
      # Convert string representations of booleans to actual booleans (weird, but it works)
      case value.downcase
      when 'true'
        'true'
      when 'false'
        'false'
      when 'null', ''
        'null'
      else
        # Quote if contains special characters or looks like other types
        if value.match(/[:\[\]{}|>@`]/) || value.start_with?('#') || value =~ /^\d+$/
          value.inspect
        else
          value
        end
      end
    when Numeric, TrueClass, FalseClass, NilClass
      value.to_s
    else
      value.to_yaml.strip
    end
  end

  def get_nested_value(hash, keys)
    keys.reduce(hash) do |current, key|
      return nil unless current.is_a?(Hash)

      current[key] || current[key.to_sym]
    end
  end

  def set_nested_value(hash, keys, value)
    *path, final_key = keys
    target = path.reduce(hash) { |current, key| current[key] ||= {} }
    target[final_key] = value
  end
end

# Run the script if called directly
UpstreamSettingsSync.new.run if __FILE__ == $PROGRAM_NAME
