# frozen_string_literal: true

desc 'Backfill user account id records for TestUserDashboard::TudAccount'
task backfill_user_account_for_tud_accounts: :environment do
  def get_nil_user_account_ids
    TestUserDashboard::TudAccount.where(user_account_id: nil)
  end

  def nil_user_account_ids_count_message(nil_user_account_id_count)
    Rails.logger.info('[BackfillUserAccountForTudAccounts] TestUserDashboard::TudAccount ' \
                      "with user_account_id: nil, count: #{nil_user_account_id_count}")
  end

  Rails.logger.info('[BackfillUserAccountForTudAccounts] Starting rake task')
  starting_nil_user_account_ids = get_nil_user_account_ids
  nil_user_account_ids_count_message(starting_nil_user_account_ids.count)

  starting_nil_user_account_ids.each do |record|
    account = Account.find_by(account_uuid: record.account_uuid)
    user_account = UserAccount.find_by(icn: account&.icn) ||
                   UserVerification.find_by(idme_uuid: record.idme_uuid)&.user_account ||
                   UserVerification.find_by(backing_idme_uuid: record.idme_uuid)&.user_account ||
                   UserVerification.find_by(logingov_uuid: record.logingov_uuid)&.user_account

    record.user_account_id = user_account&.id
    record.save!
  end
  Rails.logger.info('[BackfillUserAccountForTudAccounts] Finished rake task')
  nil_user_account_ids_count_message(get_nil_user_account_ids.count)
end
