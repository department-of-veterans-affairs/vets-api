# frozen_string_literal: true

class DeleteOldTransactionsJob
  include Sidekiq::Worker

  def perform
    AsyncTransaction::Base.delete_stale
  end
end
