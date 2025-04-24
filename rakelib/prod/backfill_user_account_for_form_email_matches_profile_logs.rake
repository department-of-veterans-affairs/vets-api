# frozen_string_literal: true

desc 'Backill user account id records for FormEmailMatchesProfileLog'
task backfill_user_account_for_form_email_matches_profile_logs: :environment do
  def null_user_account_id_count_message
    '[BackfillUserAccountForFormEmailMatchesProfileLog] FormEmailMatchesProfileLog with user_account_id: nil, ' \
      "count: #{user_account_nil.count}"
  end

  def user_account_nil
    FormEmailMatchesProfileLog.where(user_account_id: nil)
  end

  Rails.logger.info('[BackfillUserAccountForFormEmailMatchesProfileLog] Starting rake task')
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
              mpi_service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'idme')&.profile&.icn
        user_account = UserAccount.find_or_create_by(icn:) if icn
      end
      sub.user_account_id = user_account.uuid
      sub.save!
    end
  end
  Rails.logger.info('[BackfillUserAccountForFormEmailMatchesProfileLog] Finished rake task')
  Rails.logger.info(null_user_account_id_count_message)
end
