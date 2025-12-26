#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'
require 'open3'
require 'optparse'

# Specialized settings sync for upstream connections with exclusion support
# and comment preservation
class UpstreamSettingsSync # rubocop:disable Metrics/ClassLength
  SETTINGS_LOCAL_PATH = File.expand_path('../../config/settings.local.yml', __dir__)

  def initialize
    @options = {}
    @settings_yml_path = File.expand_path('../../config/settings.yml', __dir__)
  end

  def run
    parse_options
    validate_options
    run_service_sync
  end

  private

  def parse_options # rubocop:disable Metrics/MethodLength
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: upstream_settings_sync.rb --service SERVICE [options]'
      opts.separator ''
      opts.separator 'Internal script for upstream connection settings sync.'
      opts.separator 'This script is called by upstream-connect.sh and not meant for direct use.'
      opts.separator ''
      opts.separator 'Options:'

      opts.on('-s', '--service SERVICE', 'Service name (e.g., appeals, claims, letters)') do |service|
        @options[:service] = service
      end

      opts.on('--force', 'Overwrite existing values without prompting') do
        @options[:force] = true
      end

      opts.on('--dry-run', 'Show what would be changed without making changes') do
        @options[:dry_run] = true
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
    unless @options[:service]
      puts 'Error: --service is required'
      exit 1
    end

    # Set defaults
    @options[:exclusions] ||= []
    @options[:devops_path] ||= File.expand_path('../../../devops', __dir__)

    # Validate devops path
    unless Dir.exist?(@options[:devops_path])
      puts "Error: devops repository not found at #{@options[:devops_path]}"
      exit 1
    end
  end

  def run_service_sync # rubocop:disable Metrics/MethodLength
    service_config_path = File.join(__dir__, 'upstream_service_config.rb')

    unless File.exist?(service_config_path)
      puts "Error: Service configuration file not found: #{service_config_path}"
      exit 1
    end

    # Load the service configuration
    load service_config_path

    # Resolve service name (handle aliases)
    resolved_service = UpstreamServiceConfig.resolve_service_name(@options[:service])

    unless resolved_service
      available_services = UpstreamServiceConfig::SERVICES.keys.join(', ')
      puts "Error: Unknown service '#{@options[:service]}'. Available: #{available_services}"
      exit 1
    end

    service_config = UpstreamServiceConfig::SERVICES[resolved_service]
    settings_namespaces = service_config[:settings_namespaces]
    tunnel_settings = service_config[:tunnel_setting]
    ports = service_config[:ports]
    skipped_settings_per_namespace = service_config[:skipped_settings]

    if settings_namespaces.empty?
      puts "Error: No settings_namespaces configured for service '#{@options[:service]}'"
      exit 1
    end

    puts "Syncing settings for service '#{@options[:service]}'"
    puts ''

    # Sync each namespace with its associated tunnel settings and skipped settings
    settings_namespaces.each_with_index do |namespace, index|
      puts "Processing namespace: #{namespace}"

      # Set up namespace-specific options
      namespace_options = @options.dup
      namespace_options[:namespace] = namespace

      # Start with any global exclusions
      namespace_exclusions = @options[:exclusions] || []

      # Add skipped settings for this namespace
      if skipped_settings_per_namespace && skipped_settings_per_namespace[index]
        skipped_settings_for_namespace = skipped_settings_per_namespace[index]
        namespace_exclusions.concat(skipped_settings_for_namespace)
        puts "Auto-excluding configured skipped settings: #{skipped_settings_for_namespace.join(', ')}"
      end

      # Add tunnel setting to exclusions if it exists for this namespace
      if tunnel_settings[index] && !tunnel_settings[index].empty? # rubocop:disable Rails/Present # this isn't Rails...
        tunnel_setting = tunnel_settings[index]

        # Validate tunnel setting exists in the namespace structure
        if tunnel_setting_exists?(namespace, tunnel_setting)
          namespace_exclusions << tunnel_setting
          puts "Auto-excluding tunnel setting: #{tunnel_setting} (will be set to localhost)"
        else
          puts "Warning: Tunnel setting '#{tunnel_setting}' not found in namespace '#{namespace}' structure"
        end
      end

      # Set the combined exclusions
      namespace_options[:exclusions] = namespace_exclusions

      # Sync this namespace with exclusions
      saved_exclusions = @options[:exclusions]
      @options[:exclusions] = namespace_options[:exclusions]

      sync_namespace_with_options(namespace_options)

      @options[:exclusions] = saved_exclusions

      # Handle tunnel setting after sync
      if tunnel_settings[index] && !tunnel_settings[index].empty? && ports[index] # rubocop:disable Rails/Present # this isn't Rails...
        tunnel_setting = tunnel_settings[index]
        port = ports[index]

        if tunnel_setting_exists?(namespace, tunnel_setting)
          puts "Setting up tunnel mapping for #{namespace}.#{tunnel_setting}"
          if @options[:dry_run]
            puts "[DRY RUN] Would set #{namespace}.#{tunnel_setting} = https://localhost:#{port}"
          else
            set_tunnel_setting(namespace, tunnel_setting, "https://localhost:#{port}")
          end
        end
      end

      puts '' # Add spacing between namespaces
    end

    puts "Service sync complete for '#{@options[:service]}'"
  end

  def sync_namespace_with_options(options)
    expected_settings = get_expected_namespace_structure(options[:namespace])

    if expected_settings.empty?
      puts "Warning: No settings found for namespace '#{options[:namespace]}' in settings.yml"
      puts "This might indicate the namespace doesn't exist or has no configurable settings."
      return
    end

    puts "Found #{expected_settings.length} settings in #{options[:namespace]} namespace:"
    expected_settings.each { |setting| puts "  - #{setting}" }
    puts ''

    if options[:exclusions]&.any?
      puts "Syncing #{options[:namespace]} settings (excluding #{options[:exclusions].size} parameters)"
    end

    # Fetch and filter parameters - but only for settings that should exist
    parameters = fetch_parameters_from_service_config(expected_settings)

    filtered_parameters = filter_parameters(parameters)

    if filtered_parameters.empty?
      puts 'No parameters to sync after applying exclusions'
      return
    end

    # Update settings while preserving comments
    update_settings_preserving_comments(filtered_parameters, options[:namespace])

    puts 'Settings sync complete!'
  end

  def fetch_parameters_from_service_config(expected_settings)
    # Use the static service configuration - no user input involved
    resolved_service = UpstreamServiceConfig.resolve_service_name(@options[:service]) || @options[:service]
    service_config = UpstreamServiceConfig::SERVICES[resolved_service]
    settings_namespace = service_config[:settings_namespaces].first

    # Build parameter prefix using static configuration
    param_prefix = "/dsva-vagov/vets-api/staging/env_vars/#{settings_namespace.tr('.', '/')}"

    puts "Fetching parameters with prefix: #{param_prefix} (from service config)"
    return {} if @options[:dry_run]

    fetch_aws_parameters(param_prefix, expected_settings)
  end

  def fetch_aws_parameters(param_prefix, expected_settings) # rubocop:disable Metrics/MethodLength
    expected_param_names = expected_settings.map do |setting|
      "#{param_prefix}/#{setting.tr('.', '/')}"
    end

    # Fetch all parameters in the namespace
    cmd = [
      'aws', 'ssm', 'get-parameters-by-path',
      '--path', param_prefix,
      '--recursive',
      '--with-decryption'
    ]

    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      puts "Error fetching parameters: #{stderr}"
      exit 1
    end

    all_parameters = parse_parameter_response(stdout, param_prefix)

    # Filter to only include expected settings
    filtered_parameters = {}
    expected_param_names.each do |expected_name|
      setting_key = expected_name.sub("#{param_prefix}/", '').tr('/', '.')
      filtered_parameters[setting_key] = all_parameters[setting_key] if all_parameters.key?(setting_key)
    end

    filtered_parameters
  end

  def parse_parameter_response(stdout, param_prefix)
    response = JSON.parse(stdout)
    parameters = {}

    if response.is_a?(Array)
      parse_array_response(response, param_prefix, parameters)
    elsif response.is_a?(Hash) && response.key?('Parameters')
      parse_hash_response(response, param_prefix, parameters)
    else
      handle_unexpected_response(response)
    end

    parameters
  rescue JSON::ParserError => e
    handle_json_parse_error(e, stdout)
  end

  def parse_array_response(response, param_prefix, parameters)
    response.each do |param|
      if param.is_a?(Hash) && param.key?('Name')
        key_path = param['Name'].sub("#{param_prefix}/", '').split('/')
        parameters[key_path.join('.')] = param['Value']
      else
        puts "Warning: Unexpected parameter format: #{param.inspect}"
      end
    end
  end

  def parse_hash_response(response, param_prefix, parameters)
    response['Parameters'].each do |param|
      key_path = param['Name'].sub("#{param_prefix}/", '').split('/')
      parameters[key_path.join('.')] = param['Value']
    end
  end

  def handle_unexpected_response(response)
    puts "Error: Unexpected response format: #{response.class}"
    puts "Response: #{response.inspect}"
    exit 1
  end

  def handle_json_parse_error(error, stdout)
    puts "Error parsing parameter response: #{error.message}"
    puts "Raw output: #{stdout}"
    exit 1
  end

  def filter_parameters(parameters)
    original_count = parameters.size

    filtered = parameters.reject do |key, _|
      should_exclude_parameter?(key)
    end

    excluded_count = original_count - filtered.size

    unless @options[:dry_run]
      puts "Found #{original_count} parameters, excluding #{excluded_count}, processing #{filtered.size}"
    end

    (@options[:exclusions] || []).each do |excluded|
      excluded_params = parameters.keys.select { |key| should_exclude_parameter?(key, excluded) }
      excluded_params.each do |param|
        puts "  Excluding: #{param} (matched by: #{excluded})" unless @options[:dry_run]
      end
    end

    filtered
  end

  def should_exclude_parameter?(key, specific_exclusion = nil)
    exclusions_to_check = specific_exclusion ? [specific_exclusion] : @options[:exclusions]

    exclusions_to_check.any? do |exclusion|
      # Exact match
      key == exclusion ||
        # Namespace match for nested settings
        key.start_with?("#{exclusion}.")
    end
  end

  def update_settings_preserving_comments(parameters, namespace)
    if File.exist?(SETTINGS_LOCAL_PATH)
      update_existing_file(parameters, namespace)
    else
      create_new_file(parameters, namespace)
    end
  end

  def update_existing_file(parameters, namespace)
    # Process each parameter individually with targeted updates
    parameters.each do |param_name, param_value|
      puts "Processing parameter: #{param_name}" unless @options[:dry_run]

      # Build the full setting path
      keys = param_name.split('.')
      setting_path = namespace.split('.') + keys

      # Check current value
      current_value = get_current_value(setting_path)

      if should_update_setting?(setting_path.join('.'), current_value, param_value)
        update_single_setting(setting_path, param_value)
      end
    end

    puts "Settings updated in #{SETTINGS_LOCAL_PATH}" unless @options[:dry_run]
  end

  def update_single_setting(setting_path, new_value) # rubocop:disable Metrics/MethodLength
    return if @options[:dry_run]

    # Read the current file content
    lines = File.readlines(SETTINGS_LOCAL_PATH)

    # Find and update the specific line
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    # Track our position in the namespace hierarchy
    namespace_stack = []
    line_updated = false

    lines.each_with_index do |line, index|
      # Skip comments and empty lines for structure tracking
      next if line.strip.start_with?('#') || line.strip.empty?

      if line.match(/^(\s*)([^:\s#]+):\s*([^#]*)(#.*)?$/)
        line_indent = ::Regexp.last_match(1).length
        key = ::Regexp.last_match(2)
        value = ::Regexp.last_match(3).strip
        comment = ::Regexp.last_match(4)

        # Update namespace stack based on indentation
        # Remove items from stack if we've moved to a lower or equal indentation level
        namespace_stack.pop while namespace_stack.any? && namespace_stack.last[:indent] >= line_indent

        # Add current key to stack if it has no value (indicating a namespace)
        namespace_stack << { key:, indent: line_indent } if value.empty? || value == ''

        # Check if we're in the target namespace
        current_namespace = namespace_stack.map { |item| item[:key] }
        if current_namespace == namespace_path && key == setting_key
          formatted_value = format_yaml_value(new_value)
          # Preserve any existing comment
          comment_part = comment ? " #{comment}" : ''
          lines[index] = "#{::Regexp.last_match(1)}#{key}: #{formatted_value}#{comment_part}\n"
          line_updated = true
          break
        end
      end
    end

    # If we didn't find the setting, add it
    lines = add_new_setting_to_lines(lines, setting_path, new_value) unless line_updated

    # Write back the modified lines
    File.write(SETTINGS_LOCAL_PATH, lines.join)
  end

  def add_new_setting_to_lines(lines, setting_path, new_value) # rubocop:disable Metrics/MethodLength
    namespace_path = setting_path[0..-2]
    setting_key = setting_path.last

    if namespace_path.empty?
      # Root level setting - add at end
      formatted_value = format_yaml_value(new_value)
      lines << "#{setting_key}: #{formatted_value}\n"
      return lines
    end

    # Try to find existing namespace to insert into
    namespace_stack = []
    best_match_line = -1
    best_match_depth = -1

    lines.each_with_index do |line, index|
      # Skip comments and empty lines for structure tracking
      next if line.strip.start_with?('#') || line.strip.empty?

      if line.match(/^(\s*)([^:\s#]+):\s*([^#]*)(#.*)?$/)
        line_indent = ::Regexp.last_match(1).length
        key = ::Regexp.last_match(2)
        value = ::Regexp.last_match(3).strip

        # Update namespace stack based on indentation
        namespace_stack.pop while namespace_stack.any? && namespace_stack.last[:indent] >= line_indent

        # Add current key to stack if it has no value (indicating a namespace)
        namespace_stack << { key:, indent: line_indent, line: index } if value.empty? || value == ''

        # Check if current namespace matches part of our target path
        current_namespace = namespace_stack.map { |item| item[:key] }

        # Find the deepest matching namespace
        if namespace_path[0...current_namespace.length] == current_namespace &&
           current_namespace.length > best_match_depth
          best_match_depth = current_namespace.length
          best_match_line = index
        end
      end
    end

    if best_match_depth.positive?
      # Found a partial namespace match - insert after the best match
      remaining_path = namespace_path[best_match_depth..]
      insert_point = find_namespace_end(lines, best_match_line)
      insert_nested_setting(lines, insert_point, remaining_path, setting_key, new_value, best_match_depth * 2)
    else
      # No existing namespace found - create complete structure at end
      create_namespace_structure_in_lines(lines, namespace_path, setting_key, new_value)
    end

    lines
  end

  def find_namespace_end(lines, start_line)
    start_indent = lines[start_line].match(/^(\s*)/)[1].length

    ((start_line + 1)...lines.length).each do |i|
      line = lines[i]
      next if line.strip.empty? || line.strip.start_with?('#')

      if line.match(/^(\s*)/)
        current_indent = ::Regexp.last_match(1).length
        # If we find a line at the same or lower indentation, we've reached the end
        return i if current_indent <= start_indent
      end
    end

    lines.length # If no end found, insert at very end
  end

  def insert_nested_setting(lines, insert_point, remaining_path, setting_key, new_value, base_indent) # rubocop:disable Metrics/ParameterLists
    # Create the remaining namespace structure and the setting
    remaining_path.each_with_index do |namespace_key, depth|
      indent = base_indent + (depth * 2)
      lines.insert(insert_point, "#{' ' * indent}#{namespace_key}:\n")
      insert_point += 1
    end

    # Add the final setting
    final_indent = base_indent + (remaining_path.length * 2)
    formatted_value = format_yaml_value(new_value)
    lines.insert(insert_point, "#{' ' * final_indent}#{setting_key}: #{formatted_value}\n")
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

  def create_new_file(parameters, namespace)
    return if @options[:dry_run]

    # Build settings hash
    settings = {}
    parameters.each do |param_name, param_value|
      keys = param_name.split('.')
      setting_path = namespace.split('.') + keys
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

    settings = YAML.safe_load_file(SETTINGS_LOCAL_PATH, aliases: true) || {}
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

  def format_yaml_value(value) # rubocop:disable Metrics/MethodLength
    case value
    when String
      # Check if it's a JSON array string and convert to YAML array format
      if value.match(/^\[.*\]$/)
        begin
          parsed_array = JSON.parse(value)
          return "\n" + parsed_array.map { |item| "  - #{item}" }.join("\n") if parsed_array.is_a?(Array) # rubocop:disable Style/StringConcatenation
        rescue JSON::ParserError
          # Fall through to normal string handling
        end
      end

      # Convert string representations of booleans to actual booleans (weird, but it works)
      case value.downcase
      when 'true'
        'true'
      when 'false'
        'false'
      when 'null', ''
        'null'
      else
        # Quote if contains special characters or looks like other types, except URLs and arrays
        if (value.match(/[\[\]{}|>@`]/) || value.start_with?('#') || value =~ /^\d+$/) &&
           !value.match(%r{^https?://}) && !value.match(/^[\w.-]+:\d+$/) && !value.match(/^\[.*\]$/)
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

  def get_expected_namespace_structure(namespace)
    unless File.exist?(@settings_yml_path)
      puts "Warning: settings.yml not found at #{@settings_yml_path}"
      return nil
    end

    begin
      # Read the raw content and process ERB, but skip actual evaluation
      # We just want the structure, not the actual ENV values
      raw_content = File.read(@settings_yml_path)

      # Replace ERB tags with placeholder values to get structure
      processed_content = raw_content.gsub(/<%= ENV\[['"][^'"]+['"]\] %>/, 'placeholder')

      settings_yml = YAML.safe_load(processed_content, aliases: true)
      namespace_parts = namespace.split('.')

      # Navigate to the namespace in settings.yml
      current_section = settings_yml
      namespace_parts.each do |part|
        return nil unless current_section.is_a?(Hash) && current_section.key?(part)

        current_section = current_section[part]
      end

      # Extract all keys in this namespace (recursively get all setting paths)
      extract_setting_paths(current_section)
    rescue => e
      puts "Error reading settings.yml: #{e.message}"
      nil
    end
  end

  def extract_setting_paths(hash, path = [])
    paths = []

    return paths unless hash.is_a?(Hash)

    hash.each do |key, value|
      current_path = path + [key]

      if value.is_a?(Hash)
        # Recurse into nested hashes
        paths.concat(extract_setting_paths(value, current_path))
      else
        # This is a leaf setting - add the path
        paths << current_path.join('.')
      end
    end

    paths
  end

  def tunnel_setting_exists?(namespace, tunnel_setting)
    expected_settings = get_expected_namespace_structure(namespace)
    return false unless expected_settings

    # Check if the tunnel setting exists as a direct setting in this namespace
    expected_settings.include?(tunnel_setting)
  end

  def set_tunnel_setting(namespace, tunnel_setting, value)
    # Use our existing update_single_setting method to add the tunnel setting
    setting_path = namespace.split('.') + [tunnel_setting]

    begin
      update_single_setting(setting_path, value)
      puts "Successfully added #{namespace}.#{tunnel_setting} = #{value}"
    rescue => e
      puts "Error adding tunnel setting: #{e.message}"
      exit(1)
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
