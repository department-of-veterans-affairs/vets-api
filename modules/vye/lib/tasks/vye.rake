# frozen_string_literal: true

namespace :vye do
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
end
