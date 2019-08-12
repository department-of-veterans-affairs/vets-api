# frozen_string_literal: true

class DeleteOldPiiLogsJob
  include Sidekiq::Worker

  sidekiq_options(unique_for: 30.minutes, retry: false)

  EXPIRATION_TIME = 2.weeks

  def perform
    PersonalInformationLog.where(
      'created_at < ?', EXPIRATION_TIME.ago
    ).delete_all
  end
end
