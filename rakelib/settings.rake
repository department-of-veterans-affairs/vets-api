require 'yaml'

namespace :settings do
  desc 'Convert a Settings path to yaml'
  task :convert_to_yaml, [:settings_path] => :environment do |t, args|

    settings =
      if args[:settings_path].blank?
        Settings
      else
        settings_path = args[:settings_path].to_s.gsub('Settings.', '')
        Settings.dig(*settings_path.split("."))
      end

    unless settings.respond_to?(:to_h)
      puts
      puts settings
      puts
      exit(0)
    end

    settings_yaml = YAML.dump(settings.to_h.deep_transform_keys(&:to_s))

    puts
    puts settings_yaml
    puts
  end
end

# Usage

#--- With arg
# the arg is the dot notation path of the desired Settings group
#
# rake settings:convert_to_yaml['form_10_10cg.poa.s3']
#
#--- No arg
# this will output all settings in a yaml file
# the Settings object is generally too long for console output
# a use case might be to output to a file
#
# rake settings:convert_to_yaml > settings-output.yaml


###* Special note for .zsh users: *###
# by default zsh can’t parse the call
#
# instead run:
# noglob rake settings:convert_to_yaml['form_10_10cg.poa.s3']
#
# you can also alias the command for repeated use
# alias rake='noglob rake'
