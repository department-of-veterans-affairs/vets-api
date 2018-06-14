# frozen_string_literal: true

class DeleteOldTransactionsJob
  include Sidekiq::Worker

  EXPIRATION_TIME = 1.month

  def perform
    AsyncTransaction::Base.where(
      'created_at < ?', EXPIRATION_TIME.ago
    ).where(
      status: AsyncTransaction::Base::COMPLETED
    ).find_each(&:destroy!)
  end

end
