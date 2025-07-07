# frozen_string_literal: true

# Create UserActionEvents
config_file_path = Rails.root.join('config', 'audit_log', 'user_action_events.yml')
unless File.exist?(config_file_path)
  Rails.logger.info('[UserActionEvent] Setup Error: UserActionEvents config file not found')
  return
end
YAML.load_file(config_file_path).each do |identifier, event_config|
  event = UserActionEvent.find_or_initialize_by(identifier:)
  event.attributes = event_config
  event.save!
rescue => e
  Rails.logger.info("[UserActionEvent] Setup Error: #{e.message}")
end
