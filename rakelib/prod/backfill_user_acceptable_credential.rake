# frozen_string_literal: true

desc 'Backill acceptable_verified_credential_at/idme_verified_credential_at for user_acceptable_verified_credentials'
task :backfill_user_acceptable_credential, [:start_uuid] => :environment do |_, args|
  def user_acceptable_credential_rails_logger_message
    '[BackfillUserAcceptableCredential] acceptable_verified_credential_at: nil, ' \
      "count: #{acceptable_verified_credential_at} " \
      'idme_verified_credential_at: nil, ' \
      "count: #{idme_verified_credential_at}" \
      "total UserAVC records, count: #{total_avc}"
  end

  def batch_range_log(start_uuid, end_uuid)
    Rails.logger.info("[BackfillUserAcceptableCredential] Batch start_uuid: #{start_uuid}, end_uuid: #{end_uuid}")
  end

  def acceptable_verified_credential_at
    UserAcceptableVerifiedCredential.where(acceptable_verified_credential_at: nil).count
  end

  def idme_verified_credential_at
    UserAcceptableVerifiedCredential.where(idme_verified_credential_at: nil).count
  end

  def total_avc
    UserAcceptableVerifiedCredential.count
  end

  Rails.logger.info('[BackfillUserAcceptableCredential] Starting rake task')
  Rails.logger.info(user_acceptable_credential_rails_logger_message)
  start_uuid = args[:start_uuid].presence
  UserAccount.where.not(icn: nil).find_in_batches(start: start_uuid, order: :asc) do |user_account_batch|
    batch_range_log(user_account_batch.first.id, user_account_batch.last.id)
    ActiveRecord::Base.logger.silence do
      user_account_batch.each do |user_account|
        Login::UserAcceptableVerifiedCredentialUpdater.new(user_account:).perform
      end
    end
  end
  Rails.logger.info('[BackfillUserAcceptableCredential] Finished rake task')
  Rails.logger.info(user_acceptable_credential_rails_logger_message)
end
