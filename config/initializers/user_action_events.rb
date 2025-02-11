# frozen_string_literal: true

module UserActionEvents
  def self.setup
    require 'user_action_events/yaml_validator'

    config = YAML.load_file(Rails.root.join('config', 'user_action_events.yml'))
    UserActionEvents::YamlValidator.validate!(config)

    config.each do |slug, event_config|
      UserActionEvent.find_or_create_by!(slug:) do |event|
        event.event_type = event_config['type']
        event.details = event_config['description']
      end
    end
  end
end

Rails.application.config.after_initialize do
  UserActionEvents.setup
end
