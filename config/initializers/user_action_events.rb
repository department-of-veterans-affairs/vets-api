# frozen_string_literal: true

Rails.application.config.after_initialize do
  config_file_path = Rails.root.join('config', 'user_action_events.yml')
  unless File.exist?(config_file_path)
    Rails.logger.info('UserActionEvents config file not found; skipping database population.')
    return
  end
  user_action_events_yaml = YAML.load_file(config_file_path)

  user_action_events_yaml.each do |identifier, event_config|
    UserActionEventCreator.new(identifier:, event_config:).perform
  end
rescue => e
  Rails.logger.error("Error loading user action event: #{e.message}")
end
