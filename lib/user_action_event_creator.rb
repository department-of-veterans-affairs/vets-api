# frozen_string_literal: true

class UserActionEventCreator
  def self.perform
    config_file_path = Rails.root.join('config', 'user_action_events.yml')
    unless File.exist?(config_file_path)
      Rails.logger.info('UserActionEvents config file not found; skipping database population.')
      return
    end
    user_action_events_yaml = YAML.load_file(config_file_path)

    user_action_events_yaml.each do |identifier, event_config|
      event = UserActionEvent.find_or_initialize_by(identifier:)
      event.attributes = event_config
      event.save!
    end
  rescue => e
    Rails.logger.error("[UserActionEvent][Setup] Error loading user action event: #{e.message}")
  end
end
