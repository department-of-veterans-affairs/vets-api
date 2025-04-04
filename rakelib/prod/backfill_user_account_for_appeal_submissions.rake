# frozen_string_literal: true

desc 'Backill user account id records for AppealSubmission forms'
task backfill_user_account_for_appeal_submissions: :environment do
  def null_user_account_id_count_message
    '[BackfillUserAccountForAppealSubmissions] AppealSubmission with user_account_id: nil, ' \
      "count: #{user_account_nil.count}"
  end

  def user_account_nil
    AppealSubmission.where(user_account: nil)
  end

  Rails.logger.info('[BackfillUserAccountForAppealSubmissions] Starting rake task')
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
        user_account = UserAccount.find_by(icn:) || UserAccount.new(icn:).save! if icn
      end
      sub.user_account = user_account
      sub.save!
    end
  end
  Rails.logger.info('[BackfillUserAccountForAppealSubmissions] Finished rake task')
  Rails.logger.info(null_user_account_id_count_message)
end
