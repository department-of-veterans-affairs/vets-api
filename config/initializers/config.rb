# frozen_string_literal: true

# ENVs from Parent Helm Chart are all lowercase.
# To keep with the convention, they should all
# be upcased in order to not disrupt other ENVs.
# This code adds an upcased version
# ENV['example'] => ENV['EXAMPLE]
ENV.each_key do |key|
  next unless key == key.downcase

  # WARNING: changing this will cause all deployed
  # settings with ENVs to be nil.
  ENV[key.upcase] = ENV.fetch(key)
end

Config.setup do |config|
  # Name of the constant exposing loaded settings
  config.const_name = 'Settings'

  # Ability to remove elements of the array set in earlier loaded settings file. For example value: '--'.
  #
  # config.knockout_prefix = nil

  # Overwrite arrays found in previously loaded settings file. When set to `false`, arrays will be merged.
  #
  # config.overwrite_arrays = true

  # Load environment variables from the `ENV` object and override any settings defined in files.
  #
  config.use_env = true

  # Define ENV variable prefix deciding which variables to load into config.
  #
  config.env_prefix = 'SETTINGS'
  # What string to use as level separator for settings loaded from ENV variables. Default value of '.' works well
  # with Heroku, but you might want to change it for example for '__' to easy override settings from command line, where
  # using dots in variable names might not be allowed (eg. Bash).
  #
  config.env_separator = '__'

  # Ability to process variables names:
  #   * nil  - no change
  #   * :downcase - convert to lower case
  #
  config.env_converter = :downcase

  # Parse numeric values as integers instead of strings.
  #
  config.env_parse_values = true

  # Whether nil values will overwrite an existing value when merging configs. Default: true
  #
  config.merge_nil_values = true
end
