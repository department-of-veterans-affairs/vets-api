# frozen_string_literal: true

desc 'Backfill user account id records for TestUserDashboard::TudAccountAvailabilityLogs'
task backfill_user_account_for_tud_account_availability_logs: :environment do
  def get_nil_user_account_ids
    TestUserDashboard::TudAccountAvailabilityLog.where(user_account_id: nil)
  end

  def nil_user_account_ids_count_message(nil_user_account_id_count)
    Rails.logger.info('[BackfillUserAccountForTudAccountAvailabilityLogs] ' \
                      'TestUserDashboard::TudAccountAvailabilityLog ' \
                      "with user_account_id: nil, count: #{nil_user_account_id_count}")
  end

  Rails.logger.info('[BackfillUserAccountForTudAccountAvailabilityLogs] Starting rake task')
  starting_nil_user_account_ids = get_nil_user_account_ids
  nil_user_account_ids_count_message(starting_nil_user_account_ids.count)

  starting_nil_user_account_ids.each do |record|
    account = Account.find_by(uuid: record.account_uuid)
    user_account = UserAccount.find_by(icn: account&.icn)

    unless user_account
      tud_account = TestUserDashboard::TudAccount.find_by(account_uuid: record.account_uuid)
      user_account = UserVerification.find_by(idme_uuid: tud_account.idme_uuid)&.user_account ||
                     UserVerification.find_by(backing_idme_uuid: tud_account.idme_uuid)&.user_account ||
                     UserVerification.find_by(logingov_uuid: tud_account.logingov_uuid)&.user_account
    end
    record.user_account_id = user_account&.id
    record.save!
  end
  Rails.logger.info('[BackfillUserAccountForTudAccountAvailabilityLogs] Finished rake task')
  nil_user_account_ids_count_message(get_nil_user_account_ids.count)
end
