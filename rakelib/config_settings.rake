require 'yaml'

VALID_ENV_REGEX = /<%= ENV\['[A-Z0-9_]+(?:__[A-Z0-9_]+)*'\] %>/

namespace :settings do

  task :validate => [:validate_alphabetical, :validate_key_set, :validate_env_convention]

  task :validate_alphabetical do
    yaml_files = [
      'config/settings.yml',
      'config/settings/development.yml',
      'config/settings/test.yml',
    ]
    errors = []

    yaml_files.each do |file|
      data = YAML.load_file(file)
      unordered_keys = find_unordered_keys(data)
      unless unordered_keys.empty?
        errors << "Keys in #{file} are not in alphabetical order:\n  #{unordered_keys.join("\n  ")}"
      end
    end

    if errors.empty?
      puts "All config files have keys in alphabetical order."
    else
      puts errors.join("\n")
      exit 1
    end
  end

  task :validate_key_set do
    reference_file = 'config/settings.yml'
    comparison_files = ['config/settings/development.yml', 'config/settings/test.yml']

    reference_keys = extract_keys(YAML.load_file(reference_file))
    errors = []

    comparison_files.each do |file|
      file_keys = extract_keys(YAML.load_file(file))
      missing_keys = reference_keys - file_keys
      extra_keys = file_keys - reference_keys

      unless missing_keys.empty? && extra_keys.empty?
        errors << "\nKey mismatch in #{file}:\n  Missing keys:\n    #{missing_keys.join("\n    ")}\n  Extra keys:\n    #{extra_keys.join("\n    ")}"
      end
    end

    if errors.empty?
      puts "All config files have the same nested keys as settings.yml"
    else
      puts errors.join("\n")
      exit 1
    end
  end

  task :validate_env_convention do
    yaml_files = [
      'config/settings.yml',
      'config/settings/development.yml',
      'config/settings/test.yml',
    ]
    errors = []

    yaml_files.each do |file|
      data = YAML.load_file(file)
      invalid_env_keys = validate_envs(data)
      unless invalid_env_keys.empty?
        errors << "Invalid ENV format in #{file}:\n  #{invalid_env_keys.join("\n  ")}"
      end
    end

    if errors.empty?
      puts "All ENV keys match the required convention."
    else
      puts errors.join("\n")
      exit 1
    end
  end
end

# Recursively checks if keys in a hash are in alphabetical order
def find_unordered_keys(hash, parent_key = "")
  return [] unless hash.is_a?(Hash)

  keys = hash.keys.map(&:to_s)
  unordered = keys.each_cons(2).select { |a, b| a > b }.map { |k| "#{parent_key}#{k}" }

  hash.flat_map { |key, value| find_unordered_keys(value, "#{parent_key}#{key}.") } + unordered
end

# Recursively extract all nested keys from a hash
def extract_keys(hash, parent_key = "")
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
      unless yaml_data[key] == "<%= ENV['#{env_key}'] %>"
        incorrect_key = env_key.downcase.gsub('__','/')
        errors << "ENV is incorrect for #{incorrect_key} should be: #{env_key}"
      end
    end
  end
  errors
end
