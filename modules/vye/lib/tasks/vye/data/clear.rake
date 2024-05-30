# frozen_string_literal: true

namespace :vye do
  namespace :data do
    desc 'Clear VYE data from the database'
    task clear: :environment do |_cmd, _args|
      Vye::AddressChange.destroy_all
      Vye::DirectDepositChange.destroy_all
      Vye::Verification.destroy_all
      Vye::Award.destroy_all
      Vye::UserInfo.destroy_all

      Vye::PendingDocument.destroy_all

      Vye::UserProfile.destroy_all
      Vye::BdnClone.destroy_all
    end
  end
end
