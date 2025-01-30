# frozen_string_literal: true

class UserActionEventsCleanupJob
  include Sidekiq::Job

  sidekiq_options unique_for: 30.minutes, retry: false

  EXPIRATION_TIME = 1.year

  def perform
    events = UserActionEvent.where('created_at < ?', EXPIRATION_TIME.ago)
    events.find_each do |event|
      UserAction.where(user_action_event_id: event.id).delete_all
      event.delete
    end
  end
end
