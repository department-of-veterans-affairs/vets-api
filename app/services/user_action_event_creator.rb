# frozen_string_literal: true

class UserActionEventCreator
  attr_reader :identifier, :details, :event_type

  def initialize(identifier:, event_config:)
    @identifier = identifier
    @details = event_config['details']
    @event_type = event_config['event_type']
  end

  def perform
    validate_event_arguments
    create_or_update_user_action_event
  end

  private

  def validate_event_arguments
    raise 'Event is missing an identifier' unless identifier
    raise "Event #{identifier} is missing details" unless details
    raise "Event #{identifier} is missing an event_type" unless event_type
    raise "Event #{identifier} has an invalid event_type" unless UserActionEvent.event_types.include?(event_type)
  end

  def create_or_update_user_action_event
    user_action_event.details = details
    user_action_event.event_type = event_type
    user_action_event.save!
    user_action_event
  end

  def user_action_event
    @user_action_event ||= UserActionEvent.find_or_initialize_by(identifier:)
  end
end
