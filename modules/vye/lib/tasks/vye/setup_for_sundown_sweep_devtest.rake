# frozen_string_literal: true

# this task creates database rows to run sundown sweep in a local development sandbox
# Look at the BdnClone model for details on the various states. There's a matrix at the top

# To run the process in a manner that more or less closely resembles prodcution, do the following:
# 1) In a terminal window at the vets-api root, run: foreman start -m all=1,clamd=0,freshclam=0
# 2) Open up a browser and navigate to http://localhost:3000/sidekiq/busy
#    You can see the job queue there and this job when it runs
# 3) In another terminal window at the vets-api root, run this rake task: rake vye:create_sundown_sweep_dev_sandbox_data
#    This creates the necessary database rows to run sundown sweep in a local development sandbox
# 4) Once step 3 is complete, run rails c to start a rails console
#    You can run the sundown sweep job in the console with: Vye::SundownSweepJob.new.perform
namespace :vye do
  desc 'create database rows to run sundown sweep in a local development sandbox'
  task create_sundown_sweep_dev_sandbox_data: :environment do |_cmd, _args|
    # clear out the log file
    Rake::Task['log:clear'].invoke

    puts 'Clearing out BdnClone'
    Vye::BdnClone.destroy_all
    puts 'Clearing out related table data for Sundown Sweep test'
    Vye::Verification.destroy_all
    Vye::PendingDocument.destroy_all

    # this should blow away the address changes, awards, & direct deposit changes
    # via referential integrity delete cascade rules
    # we already blew away the verifications
    Vye::UserInfo.destroy_all

    # You have to provide a value for scrypt.salt or you get an error trying to create a UserProfile
    Vye.settings.scrypt.salt = '1'

    puts 'Creating BdnClone row that will be deleted'
    create(:vye_bdn_clone_with_user_info_children, transact_date: Time.Zone.today - 2.days)

    puts 'Creating active BdnClone row'
    create(
      :vye_bdn_clone_with_user_info_children, :active, transact_date: Time.Zone.today - 1.day
    )

    puts 'Creating freshly imported BdnClone row'
    create(:vye_bdn_clone_with_user_info_children, is_active: false)

    puts 'BdnClones created'
    Vye::BdnClone.all.find_each { |bdn_clone| puts bdn_clone.inspect }

    puts "\nUserProfiles created"
    Vye::UserProfile.all.find_each { |user_profile| puts user_profile.inspect }

    puts "\nUserInfos created"
    Vye::UserInfo.all.find_each { |user_info| puts user_info.inspect }

    puts "\nPendingDocuments created"
    Vye::PendingDocument.all.find_each { |pending_document| puts pending_document.inspect }

    puts "\nVerifications created"
    Vye::Verification.all.find_each { |verification| puts verification.inspect }

    puts "\nAddressChanges created"
    Vye::AddressChange.all.find_each { |address_change| puts address_change.inspect }

    puts "\nAwards created"
    Vye::Award.all.find_each { |award| puts award.inspect }

    puts "\nDirectDepositChanges created"
    Vye::DirectDepositChange.all.find_each { |direct_deposit_change| puts direct_deposit_change.inspect }
  end
end
