#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'
require 'open3'
require 'optparse'

class SettingsSync
  FORWARD_PROXY_PATTERN = /fwdproxy-(\w+)\.vfs\.va\.gov:(\d+)/
  SETTINGS_LOCAL_PATH = File.expand_path('../config/settings.local.yml', __dir__)
  TEST_SETTINGS_LOCAL_PATH = File.expand_path('../config/settings/test.local.yml', __dir__)
  DEVOPS_PATH = File.expand_path('../../devops', __dir__)
  SSM_PARAMETERS_SCRIPT = File.join(DEVOPS_PATH, 'utilities/ssm-parameters.sh')
  SSM_PORTFORWARDING_SCRIPT = File.join(DEVOPS_PATH, 'utilities/ssm-portforwarding.sh')

  def initialize
    @options = {}
    @forward_proxy_tunnels = {}
    @local_port_counter = 4000
  end

  def run
    parse_options
    validate_requirements

    puts "Syncing settings for namespace '#{@options[:namespace]}' from environment '#{@options[:environment]}'"

    # Load existing settings.local.yml
    local_settings = load_local_settings

    # Get parameter store values for the namespace
    param_values = fetch_parameter_store_values

    if param_values.empty?
      puts "No parameters found for namespace '#{@options[:namespace]}' in environment '#{@options[:environment]}'"
      return
    end

    # Process each parameter
    param_values.each do |param_name, param_value|
      process_parameter(local_settings, param_name, param_value)
    end

    # Save updated settings
    save_local_settings(local_settings)

    # Start forward proxy tunnels if any were configured
    start_forward_proxy_tunnels if @forward_proxy_tunnels.any?

    puts "\nSettings sync complete!"
  end

  private

  def parse_options
    parser = create_option_parser
    parser.parse!
    validate_required_options(parser)
  end

  def create_option_parser
    OptionParser.new do |opts|
      setup_banner_and_description(opts)
      setup_command_line_options(opts)
    end
  end

  def setup_banner_and_description(opts)
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
    opts.separator ''
    opts.separator 'Sync settings from AWS Parameter Store to settings.local.yml'
    opts.separator ''
    opts.separator 'Options:'
  end

  def setup_command_line_options(opts)
    opts.on('-n', '--namespace NAMESPACE', "Settings namespace (e.g., 'mhv.rx')") do |namespace|
      @options[:namespace] = namespace
    end

    opts.on('-e', '--environment ENV', "Environment (e.g., 'staging', 'dev', 'prod')") do |env|
      @options[:environment] = env
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

  def validate_required_options(parser)
    return if @options[:namespace] && @options[:environment]

    puts 'Error: Both --namespace and --environment are required'
    puts parser
    exit 1
  end

  def validate_requirements
    # Check for devops repository
    unless Dir.exist?(DEVOPS_PATH)
      puts "Error: devops repository not found at #{DEVOPS_PATH}"
      puts 'Please ensure the devops repo is cloned as a sibling to vets-api'
      exit 1
    end

    # Check for required scripts
    unless File.executable?(SSM_PARAMETERS_SCRIPT)
      puts "Error: SSM parameters script not found or not executable: #{SSM_PARAMETERS_SCRIPT}"
      exit 1
    end

    unless File.executable?(SSM_PORTFORWARDING_SCRIPT)
      puts "Error: SSM port forwarding script not found or not executable: #{SSM_PORTFORWARDING_SCRIPT}"
      exit 1
    end

    puts "✅ Found devops utilities at #{DEVOPS_PATH}"
  end

  def load_local_settings
    if File.exist?(SETTINGS_LOCAL_PATH)
      YAML.load_file(SETTINGS_LOCAL_PATH) || {}
    else
      {}
    end
  rescue Psych::SyntaxError => e
    puts "Error parsing existing settings.local.yml: #{e.message}"
    exit 1
  end

  def fetch_parameter_store_values
    param_prefix = build_parameter_prefix
    puts "Fetching parameters with prefix: #{param_prefix}"

    stdout, stderr, status = execute_ssm_command(param_prefix)
    handle_command_error(stderr, param_prefix) unless status.success?

    parse_parameter_response(stdout, param_prefix)
  end

  def build_parameter_prefix
    "/dsva-vagov/vets-api/#{@options[:environment]}/env_vars/#{@options[:namespace].gsub('.', '/')}"
  end

  def execute_ssm_command(param_prefix)
    cmd = [SSM_PARAMETERS_SCRIPT, param_prefix.to_s, '--recursive', '--decrypt', '--json']
    Open3.capture3(*cmd)
  end

  def handle_command_error(stderr, param_prefix)
    puts "Error fetching parameters: #{stderr}"
    puts "Command: #{[SSM_PARAMETERS_SCRIPT, param_prefix, '--recursive', '--decrypt', '--json'].join(' ')}"
    exit 1
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

  def process_parameter(local_settings, param_name, param_value)
    puts "\nProcessing parameter: #{param_name}"

    # Convert dot notation to nested hash structure
    keys = param_name.split('.')
    setting_path = [@options[:namespace].split('.'), keys].flatten

    # Check if value contains forward proxy URL
    param_value = handle_forward_proxy(param_value, setting_path.join('.')) if param_value.match(FORWARD_PROXY_PATTERN)

    # Check if setting already exists
    current_value = get_nested_value(local_settings, setting_path)

    if current_value.nil?
      puts "  Setting new value: #{param_value}"
      set_nested_value(local_settings, setting_path, param_value) unless @options[:dry_run]
    elsif current_value != param_value
      if @options[:force] || prompt_overwrite(setting_path.join('.'), current_value, param_value)
        puts "  Updating value: #{current_value} → #{param_value}"
        set_nested_value(local_settings, setting_path, param_value) unless @options[:dry_run]
      else
        puts '  Skipping (keeping existing value)'
      end
    else
      puts '  No change needed (values match)'
    end
  end

  def handle_forward_proxy(url, setting_key)
    match = url.match(FORWARD_PROXY_PATTERN)
    return url unless match

    env = match[1]
    remote_port = match[2]
    local_port = find_available_port

    puts "  Detected forward proxy URL: #{url}"
    puts "  Setting up tunnel: #{env}:#{remote_port} → localhost:#{local_port}"

    # Store tunnel configuration for later startup
    @forward_proxy_tunnels[setting_key] = {
      env:,
      remote_port:,
      local_port:,
      original_url: url
    }

    # Return modified URL pointing to local port
    url.gsub(FORWARD_PROXY_PATTERN, "localhost:#{local_port}")
  end

  def find_available_port
    port = @local_port_counter
    @local_port_counter += 1

    # Check if port is actually available
    while system("netstat -ln | grep :#{port} > /dev/null 2>&1")
      port = @local_port_counter
      @local_port_counter += 1
    end

    port
  end

  def prompt_overwrite(key, current_value, new_value)
    return true if @options[:dry_run]

    puts "  Setting '#{key}' already exists:"
    puts "    Current: #{current_value}"
    puts "    New:     #{new_value}"
    print '  Overwrite? [y/N]: '

    response = $stdin.gets.chomp.downcase
    %w[y yes].include?(response)
  end

  def get_nested_value(hash, keys)
    keys.reduce(hash) do |current, key|
      return nil unless current.is_a?(Hash)

      current[key] || current[key.to_sym]
    end
  end

  def set_nested_value(hash, keys, value)
    *path, final_key = keys

    target = path.reduce(hash) do |current, key|
      current[key] ||= {}
    end

    target[final_key] = value
  end

  def save_local_settings(settings)
    return if @options[:dry_run]

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(SETTINGS_LOCAL_PATH))
    FileUtils.mkdir_p(File.dirname(TEST_SETTINGS_LOCAL_PATH))

    # Write YAML with nice formatting
    yaml_content = "---\n#{settings.to_yaml.lines[1..].join}"

    File.write(SETTINGS_LOCAL_PATH, yaml_content)
    puts "\nSettings saved to #{SETTINGS_LOCAL_PATH}"

    # Also save to test environment settings
    save_test_settings(settings)
  end

  def save_test_settings(settings)
    # Load existing test settings if present
    test_settings = if File.exist?(TEST_SETTINGS_LOCAL_PATH)
                      YAML.safe_load_file(TEST_SETTINGS_LOCAL_PATH, permitted_classes: [Symbol]) || {}
                    else
                      {}
                    end

    # Deep merge the new settings into test settings
    deep_merge!(test_settings, settings)

    # Write YAML with nice formatting
    yaml_content = "---\n#{test_settings.to_yaml.lines[1..].join}"

    File.write(TEST_SETTINGS_LOCAL_PATH, yaml_content)
    puts "Settings also saved to #{TEST_SETTINGS_LOCAL_PATH}"
  end

  def deep_merge!(target, source)
    source.each do |key, value|
      if value.is_a?(Hash) && target[key].is_a?(Hash)
        deep_merge!(target[key], value)
      else
        target[key] = value
      end
    end
    target
  end

  def start_forward_proxy_tunnels
    return if @options[:dry_run]

    puts "\nForward proxy tunnels:"

    @forward_proxy_tunnels.each_value do |config|
      puts "  #{config[:original_url]} → localhost:#{config[:local_port]}"

      # Use the devops ssm-portforwarding.sh script
      tunnel_cmd = "#{SSM_PORTFORWARDING_SCRIPT} forward-proxy #{config[:env]} " \
                   "#{config[:local_port]} #{config[:remote_port]}"

      puts "  Note: You'll need to run this manually:"
      puts "    #{tunnel_cmd}"
      puts ''
    end
  end
end

# Run the script if called directly
SettingsSync.new.run if __FILE__ == $PROGRAM_NAME
