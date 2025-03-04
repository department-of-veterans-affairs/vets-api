# frozen_string_literal: true

class UserActionsCleanupJob
  include Sidekiq::Job

  sidekiq_options unique_for: 30.minutes, retry: false

  EXPIRATION_TIME = 1.year

  def perform
    UserAction.where(created_at: ...EXPIRATION_TIME.ago).delete_all
  end
end
