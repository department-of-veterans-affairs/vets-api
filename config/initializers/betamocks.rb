# frozen_string_literal: true

Betamocks.configure do |config|
<<<<<<< f55b007fa54585abc265963ac2fda8dfff71b73d
  config.config_path = File.join(Rails.root, 'config', 'betamocks', 'betamocks.yml')
=======
  config.enabled = Settings.betamocks_enabled
  config.cache_dir = File.join(Rails.root, Settings.betamocks_cache_path)
  config.services_config = File.join(Rails.root, 'config', 'betamocks', 'services_config.yml')
>>>>>>> gs
end
