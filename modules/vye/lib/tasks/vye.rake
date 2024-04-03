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

  namespace :data do
    desc 'Clear VYE data from the database'
    task clear: :environment do |_cmd, _args|
      Vye::AddressChange.destroy_all
      Vye::DirectDepositChange.destroy_all
      Vye::Verification.destroy_all
      Vye::Award.destroy_all
      Vye::UserInfo.destroy_all

      Vye::PendingDocument.destroy_all

      Vye::UserProfile.destroy_all
    end

    desc 'Build YAML files to load for development from team sensitive data'
    task build: :environment do |_cmd, _args|
      source = Pathname('/projects/va.gov-team-sensitive')
      target = Rails.root / 'tmp'
      handles = nil

      build = Vye::StagingData::Build.new(target:) do |paths|
        handles =
          paths
          .transform_values do |value|
            (source / value).open
          end
      end

      build.dump
      handles.each_value(&:close)
    end

    desc 'Load development YAML files into the database'
    task :load, [:path] => :environment do |_cmd, args|
      raise 'load path is required' if args[:path].nil?

      root = Pathname(args[:path])
      files = root.glob('**/*.yaml')
      raise "No files found in #{root}" if files.empty?

      files.each do |file|
        source = :team_sensitive
        data = YAML.safe_load(file.read, permitted_classes: [Date, DateTime, Symbol, Time])
        records = data.slice(:profile, :info, :address, :awards, :pending_documents)
        Vye::LoadData.new(source:, records:)
      end
    end
  end
end
