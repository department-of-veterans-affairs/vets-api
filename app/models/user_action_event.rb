# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  validates :details, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :event_type, presence: true

  def self.setup
    config_file_path = Rails.root.join('config', 'user_action_events.yml')
    raise 'Config file not found' unless File.exist?(config_file_path)

    user_action_events_yaml = YAML.load_file(config_file_path)

    user_action_events_yaml.each do |identifier, event_config|
      event = UserActionEvent.find_or_initialize_by(identifier:)
      event.attributes = event_config
      event.save! if event.changed?
    end
  rescue => e
    raise "[#{name}][Setup] Error: #{e.message}"
  end
end
