# frozen_string_literal: true

module UserActionEvents
  def self.setup
    return unless table_exists_with_columns?

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

  def self.table_exists_with_columns?
    connection = ActiveRecord::Base.connection
    return false unless connection.table_exists?(:user_action_events)

    columns = connection.columns(:user_action_events).map(&:name)
    columns.include?('event_type') && columns.include?('slug')
  rescue ActiveRecord::NoDatabaseError
    false
  end
end

Rails.application.config.after_initialize do
  UserActionEvents.setup
end
