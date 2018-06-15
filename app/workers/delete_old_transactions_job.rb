# frozen_string_literal: true

class DeleteOldTransactionsJob
  include Sidekiq::Worker
  # :nocov:
  def perform
    AsyncTransaction::Base.delete_stale!
  end
  # :nocov:
end
