# frozen_string_literal: true

desc 'Backill user account id records for AsyncTransaction::Base records'
task backfill_user_account_for_async_transactions: :environment do
  def null_user_account_id_count_message
    '[BackfillUserAccountForAsyncTransactions] AsyncTransaction::Base with user_account_id: nil, ' \
      "count: #{user_account_nil.count}"
  end

  def user_account_nil
    AsyncTransaction::Base.where(user_account: nil)
  end

  Rails.logger.info('[BackfillUserAccountForAsyncTransactions] Starting rake task')
  Rails.logger.info(null_user_account_id_count_message)
  mpi_service = MPI::Service.new
  user_account_nil.find_in_batches(batch_size: 1000) do |batch|
    batch.each do |sub|
      user_uuid = sub.user_uuid
      user_account = UserVerification.find_by(idme_uuid: user_uuid)&.user_account ||
                     UserVerification.find_by(backing_idme_uuid: user_uuid)&.user_account ||
                     UserVerification.find_by(logingov_uuid: user_uuid)&.user_account
      unless user_account
        icn = Account.find_by(idme_uuid: user_uuid)&.icn ||
              Account.find_by(logingov_uuid: user_uuid)&.icn ||
              mpi_service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'idme')&.profile&.icn ||
              mpi_service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'logingov')&.profile&.icn
        user_account = UserAccount.find_or_create_by(icn:) if icn
      end
      sub.user_account = user_account
      sub.save!
    end
  end
  Rails.logger.info('[BackfillUserAccountForAsyncTransactions] Finished rake task')
  Rails.logger.info(null_user_account_id_count_message)
end
