# frozen_string_literal: true

user_action_events_yaml = YAML.load_file(Rails.root.join('config', 'user_action_events.yml'))

Rails.application.config.after_initialize do
  user_action_events_yaml.each do |identifier, event_config|
    UserActionEventCreator.new(identifier:, event_config:).perform
  end
rescue => e
  Rails.logger.error("Error loading user action event: #{e.message}")
end
