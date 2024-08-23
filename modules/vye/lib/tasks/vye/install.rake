# frozen_string_literal: true

namespace :vye do
  namespace :install do
    desc 'Installs config into config/settings.local.yml'
    task config: :environment do |_cmd, _args|
      paths = {
        root: Rails.root / 'config/settings.local.yml',
        vye_root: Vye::Engine.root / 'config/settings.local.yml',
        vye_aws_credentials: Vye::Engine.root / 'config/settings/local/aws-credentials.yml'
      }

      local_settings = Config.load_files(*paths.values_at(:root, :vye_root, :vye_aws_credentials))

      paths[:root].write(local_settings.to_h.deep_stringify_keys.to_yaml, mode: 'w')
    end
  end
end
