# frozen_string_literal: true

class UserActionsCleanupJob
  include Sidekiq::Job

  def perform
    cutoff_date = 1.year.ago
    UserAction.where('created_at < ?', cutoff_date).destroy_all
  end
end
