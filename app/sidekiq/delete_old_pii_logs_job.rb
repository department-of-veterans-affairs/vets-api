# frozen_string_literal: true

class DeleteOldPiiLogsJob
  include Sidekiq::Job

  sidekiq_options unique_for: 30.minutes, retry: false

  EXPIRATION_TIME = 2.weeks
  BATCH_SIZE = 10_000

  def perform
    loop do
      records = PersonalInformationLog.where('created_at < ?', EXPIRATION_TIME.ago).limit(BATCH_SIZE)
      break if records.empty?

      records.delete_all
    end
  end
end
