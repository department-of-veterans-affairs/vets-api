# frozen_string_literal: true

desc 'Backill user account id records for InProgressForm'
task backfill_user_account_for_in_progress_forms: :environment do
  def in_progress_form_rails_logger_message
    "[BackfillUserAccountIdForInProgressForms] InProgressForm with user_account_id: nil, count: #{user_account_nil}"
  end

  def user_account_nil
    InProgressForm.where(user_account: nil).count
  end

  def get_user_verification(uuid)
    user_verification = UserVerification.find_by(idme_uuid: uuid) || UserVerification.find_by(logingov_uuid: uuid)
    user_verification&.user_account
  end

  Rails.logger.info('[BackfillUserAccountIdForInProgressForms] Starting rake task')
  Rails.logger.info(in_progress_form_rails_logger_message)
  InProgressForm.where(user_account: nil).find_each do |form|
    user_account = get_user_verification(form.user_uuid)
    next unless user_account

    form.update!(user_account:)
  end
  Rails.logger.info('[BackfillUserAccountIdForInProgressForms] Finished rake task')
  Rails.logger.info(in_progress_form_rails_logger_message)
end
