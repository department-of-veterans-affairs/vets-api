# frozen_string_literal: true

desc 'Backill user account id records for InProgressForm'
task backfill_user_account_for_in_progress_forms: :environment do
  def in_progress_form_rails_logger_message
    "[BackfillUserAccountIdForInProgressForms] InProgressForm with user_account_id: nil, count: #{user_account_nil}"
  end

  def user_account_nil
    InProgressForm.where(user_account: nil).count
  end

  def get_account_icn(uuid)
    hyphenated_uuid = "#{uuid[0, 8]}-#{uuid[8, 4]}-#{uuid[12, 4]}-#{uuid[16, 4]}-#{uuid[20, 12]}"
    account = Account.lookup_by_user_uuid(uuid) || Account.lookup_by_user_uuid(hyphenated_uuid)
    account&.icn
  end

  def get_user_verification(uuid)
    user_verification = UserVerification.find_by(idme_uuid: uuid) || UserVerification.find_by(logingov_uuid: uuid)
    user_verification&.user_account
  end

  Rails.logger.info('[BackfillUserAccountIdForInProgressForms] Starting rake task')
  Rails.logger.info(in_progress_form_rails_logger_message)
  InProgressForm.where(user_account: nil).find_each do |form|
    account_icn = get_account_icn(form.user_uuid)
    user_account = (account_icn && UserAccount.find_by(icn: account_icn)) ||
                   get_user_verification(form.user_uuid)
    next unless user_account

    form.update!(user_account:)
  end
  Rails.logger.info('[BackfillUserAccountIdForInProgressForms] Finished rake task')
  Rails.logger.info(in_progress_form_rails_logger_message)
end
