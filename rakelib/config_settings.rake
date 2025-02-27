# frozen_string_literal: true

require 'yaml'

VALID_ENV_REGEX = /<%= ENV\['[A-Z0-9_]+(?:__[A-Z0-9_]+)*'\] %>/

namespace :settings do
  task validate: %i[validate_alphabetical validate_key_set validate_env_convention]

  task validate_alphabetical: :environment do
    yaml_files = [
      'config/settings.yml',
      'config/settings/development.yml',
      'config/settings/test.yml'
    ]
    errors = []

    yaml_files.each do |file|
      data = YAML.load_file(file, aliases: true)
      unordered_keys = find_unordered_keys(data)
      unordered_keys.reject! { |k| k.include?('21p_530') } # skips non-alphabetical archor key
      unless unordered_keys.empty?
        errors << "Keys in #{file} are not in alphabetical order:\n  #{unordered_keys.join("\n  ")}"
      end
    end

    if errors.empty?
      puts 'All config files have keys in alphabetical order.'
    else
      puts errors.join("\n")
      exit 1
    end
  end

  task validate_key_set: :environment do
    reference_file = 'config/settings.yml'
    comparison_files = ['config/settings/development.yml', 'config/settings/test.yml']

    reference_keys = extract_keys(YAML.load_file(reference_file, aliases: true))
    errors = []

    comparison_files.each do |file|
      file_keys = extract_keys(YAML.load_file(file, aliases: true))
      missing_keys = reference_keys - file_keys
      extra_keys = file_keys - reference_keys

      unless missing_keys.empty? && extra_keys.empty?
        missing_keys_message = missing_keys.join("\n    ")
        extra_keys_message = extra_keys.join("\n    ")
        error_message = "\nKey mismatch in #{file}:\n  \
                        Missing keys:\n    #{missing_keys_message}\n  \
                        Extra keys:\n    #{extra_keys_message}"
        errors << error_message
      end
    end

    if errors.empty?
      puts 'All config files have the same nested keys as settings.yml'
    else
      puts errors.join("\n")
      exit 1
    end
  end

  task validate_env_convention: :environment do
    yaml_files = [
      'config/settings.yml',
      'config/settings/development.yml',
      'config/settings/test.yml'
    ]
    errors = []

    yaml_files.each do |file|
      data = YAML.load_file(file, aliases: true)
      invalid_env_keys = validate_envs(data)
      errors << "Invalid ENV format in #{file}:\n  #{invalid_env_keys.join("\n  ")}" unless invalid_env_keys.empty?
    end

    if errors.empty?
      puts 'All ENV keys match the required convention.'
    else
      puts errors.join("\n")
      exit 1
    end
  end

  task find_common_hardcode_values: :environment do
    yaml_files = [
      'config/settings.yml',
      'config/settings/development.yml',
      'config/settings/test.yml'
    ]

    yaml_data = yaml_files.map { |file| YAML.load_file(file, aliases: true) }
    all_keys = yaml_data.flat_map(&:keys).uniq

    matching_keys = all_keys.select do |key|
      values = yaml_data.map { |data| data[key] }
      values.uniq.length == 1 # True if all values are identical
    end

    matching_keys = matching_keys.map { |key| { key => yaml_data.first[key] } }

    if matching_keys.any?
      puts 'Keys with identical values across all files:'
      matching_keys.each { |hash| puts hash.to_yaml }
    else
      puts 'No keys have matching values across all files.'
    end
  end

  # before running this rake task you must run the rg command:
  # rg 'Settings\.[a-zA-Z0-9_\.]+' -o --no-filename --type-add 'rails:*.{rb,rake}' -trails > tmp/found_settings.txt
  task check_usage: :environment do
    found_settings_file_path = 'tmp/found_settings.txt'

    unless File.exist?(found_settings_file_path)
      puts 'Error: The file tmp/found_settings.txt does not exist!'
      puts "Run the following command in CLI to generate the file:\n\n"
      puts "rg 'Settings.[a-zA-Z0-9_.]+' -o --no-filename --type=ruby > tmp/found_settings.txt\n\n"
      exit 1
    end

    rg_output = File.readlines(found_settings_file_path).map(&:strip)

    all_defined_settings = top_two_level_settings
    used_settings = rg_output.map { |line| line.gsub('Settings.', '') }.uniq

    unused_settings = []
    all_defined_settings.each do |defined_setting|
      unless used_settings.any? { |used_setting| used_setting.include?(defined_setting) }
        unused_settings << defined_setting # Add it to the unused_settings array
      end
    end

    puts "Warning: Prefill Settings are not validated\n\n"
    if unused_settings.empty?
      puts 'No unused settings found.'
    else
      puts 'Unused settings (not found with exact match search):'
      puts unused_settings
    end
  end
end

# Recursively checks if keys in a hash are in alphabetical order
def find_unordered_keys(hash, parent_key = '')
  return [] unless hash.is_a?(Hash)

  keys = hash.keys.map(&:to_s)
  unordered = keys.each_cons(2).select { |a, b| a > b }.map { |k| "#{parent_key}#{k}" }

  hash.flat_map { |key, value| find_unordered_keys(value, "#{parent_key}#{key}.") } + unordered
end

# Recursively extract all nested keys from a hash
def extract_keys(hash, parent_key = '')
  return [] unless hash.is_a?(Hash)

  keys = hash.flat_map { |key, value| ["#{parent_key}#{key}"] + extract_keys(value, "#{parent_key}#{key}.") }
  keys.sort
end

# Validate that ENV variables follow the required convention
def validate_envs(yaml_data, parent_key = nil)
  errors = []
  yaml_data.each do |key, value|
    env_key = [parent_key, key.to_s.upcase].compact.join('__')

    if value.is_a?(Hash)
      errors.concat(validate_envs(value, env_key))
    elsif value.is_a?(String) && value.match?(VALID_ENV_REGEX)
      # skip anchor keys
      next if %w[21p_530 pensions burials].any? { |s| env_key.include?(s.upcase) }

      unless yaml_data[key] == "<%= ENV['#{env_key}'] %>"
        incorrect_key = env_key.downcase.gsub('__', '/')
        errors << "ENV is incorrect for #{incorrect_key} should be: #{env_key}"
      end
    end
  end
  errors
end

# Extract only top two levels of settings
def top_two_level_settings(hash = Settings.to_h)
  keys = []
  hash.each do |key, value|
    next if value.is_a?(Hash) && value[:prefill]

    keys << key.to_s
    if value.is_a?(Hash)
      value.each_key do |sub_key|
        keys << "#{key}.#{sub_key}"
      end
    end
  end
  keys
end
