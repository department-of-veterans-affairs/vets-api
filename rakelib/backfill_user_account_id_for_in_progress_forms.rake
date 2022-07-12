# frozen_string_literal: true

desc 'Backill user account id records for InProgressForm'
task backfill_user_account_for_in_progress_forms: :environment do
  InProgressForm.where(user_account: nil).find_each do |form|
    uuid = form.user_uuid
    hyphenated_uuid = "#{uuid[0, 8]}-#{uuid[8, 4]}-#{uuid[12, 4]}-#{uuid[16, 4]}-#{uuid[20, 12]}"
    account = Account.lookup_by_user_uuid(uuid) || Account.lookup_by_user_uuid(hyphenated_uuid)
    user_account = account&.icn && UserAccount.find_by(icn: account&.icn)
    continue unless user_account
    form.update!(user_account: user_account)
  end
end
