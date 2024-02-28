# frozen_string_literal: true

namespace :vye do
  namespace :feature do
    desc 'Enables request_allowed feature flag'
    task request_allowed: :environment do |_cmd, _args|
      current_state = Flipper.enabled?(:vye_request_allowed)
      puts format('Current state vye_request_allowed is: %<current_state>s', current_state:)
      Flipper.enable :vye_request_allowed
    end
  end

  namespace :install do
    desc 'Installs config into config/settings.local.yml'
    task config: :environment do |_cmd, _args|
      engine_dev_path = Vye::Engine.root / 'config/settings.local.yml'
      local_path = Rails.root / 'config/settings.local.yml'
      local_settings = Config.load_files(local_path)

      raise "Vye config already exists in #{local_path}" if local_settings.vye

      local_path.write(engine_dev_path.read, mode: 'a')
    end
  end

  namespace :staging_data do
    desc 'Build YAML files to load for development from team sensitive data'
    task build: :environment do |_cmd, _args|
      source = Pathname('/projects/va.gov-team-sensitive')
      target = Rails.root / 'tmp/vye'

      raise format('team sensitive working directory not found at %<source>s', source:) unless source.exist?

      Vye::StagingData::Writer.new(source:, target:).perform
    end

    desc 'Load development YAML files into the database'
    task :load, [:path] => :environment do |_cmd, args|
      raise 'load path is required' if args[:path].nil?

      Vye::StagingData::Load.from_path(args[:path])
    end
  end
end
