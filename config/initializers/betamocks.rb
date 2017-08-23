# frozen_string_literal: true

Betamocks.configure do |config|
  config.config_path = File.join(Rails.root, 'config', 'betamocks', 'betamocks.yml')
end
