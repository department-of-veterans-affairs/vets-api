# frozen_string_literal: true

# rake vye:data:manual_deletions
# this task deletes the daily direct deposit and address additions,
# and nullifies related verifications

namespace :vye do
  namespace :data do
    desc 'Delete daily direct deposit and address additions, nullify related verification'
    task manual_deletions: :environment do |_cmd, _args|
      bdn_clone_ids = Vye::BdnClone.where(is_active: nil, export_ready: nil).pick(:id)
      bdn_clone_ids.each do |bdn_clone_id|
        Vye::DirectDepositChange.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).delete_all
        Vye::AddressChange.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).delete_all
        Vye::Award.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).delete_all

        # We're not worried about validations here because it wouldn't be in the table if it wasn't valid
        # so bugger off rubocop
        # rubocop:disable Rails/SkipsModelValidations
        Vye::Verification
          .joins(:user_info)
          .where(vye_user_infos: { bdn_clone_id: })
          .update_all(user_info_id: nil, award_id: nil)
        # rubocop:enable Rails/SkipsModelValidations

        # nuke user infos
        Vye::Vye::UserInfo.where(bdn_clone_id:).delete_all
        # nuke bdn_clone
        Vye::Vye::BdnClone.find(bdn_clone_id).destroy
      end
    end
  end
end
