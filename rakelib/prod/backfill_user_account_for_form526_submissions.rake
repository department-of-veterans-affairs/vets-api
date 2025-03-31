# frozen_string_literal: true

desc 'Backfill user account records for Form526Submission'
task backfill_user_account_for_form526_submissions: :environment do
  def form526_submission_rails_logger_message
    "[BackfillUserAccountForForm526Submissions] Form526Submission with user_account_id: nil, count: #{user_account_nil}"
  end

  def get_account_icn(uuid)
    hyphenated_uuid = "#{uuid[0, 8]}-#{uuid[8, 4]}-#{uuid[12, 4]}-#{uuid[16, 4]}-#{uuid[20, 12]}"
    account = Account.lookup_by_user_uuid(uuid) || Account.lookup_by_user_uuid(hyphenated_uuid)
    account&.icn
  end

  def get_user_verification(uuid)
    UserVerification.find_by(idme_uuid: uuid) ||
      UserVerification.find_by(logingov_uuid: uuid) ||
      UserVerification.find_by(backing_idme_uuid: uuid)
  end

  def user_account_nil
    Form526Submission.where(user_account: nil).count
  end

  Rails.logger.info('[BackfillUserAccountForForm526Submissions] Starting rake task')
  Rails.logger.info(form526_submission_rails_logger_message)
  Form526Submission.where(user_account: nil).find_each do |form|
    icn = get_account_icn(form.user_uuid)
    user_account = (icn && UserAccount.find_by(icn:)) ||
                   get_user_verification(form.user_uuid)&.user_account
    next unless user_account

    form.update!(user_account:)
  end
  Rails.logger.info('[BackfillUserAccountForForm526Submissions] Finished rake task')
  Rails.logger.info(form526_submission_rails_logger_message)
end
