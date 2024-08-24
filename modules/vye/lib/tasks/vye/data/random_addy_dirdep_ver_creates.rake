# frozen_string_literal: true

# rake vye:data:random_addy_dirdep_ver_creates
# this task will create 2000 random address changes, 2000 random direct deposit changes,
# and 10,000 random verification changes. The purpose of this is for sandbox testing of
# production runs for VYE.

namespace :vye do
  namespace :data do
    desc 'Make 2000 random address changes for testing'
    task random_addy_dirdep_ver_creates: :environment do |_cmd, _args|
      file = File.open('tmp/addy_dirdep_ver_creates.txt', 'w')

      random_ids = random_user_info_ids(2000)
      random_ids.each { |user_info_id| create_addy(file, user_info_id) }

      random_ids = random_user_info_ids(2000)
      random_ids.each { |user_info_id| create_direct_deposit_changes(file, user_info_id) }

      random_ids = random_user_info_ids(10_000)
      random_ids.each { |user_info_id| create_verification_changes(file, user_info_id) }

      file.close
    end

    def random_user_info_ids(amount)
      min_id = Vye::UserInfo.minimum(:id)
      max_id = Vye::UserInfo.maximum(:id)
      (min_id..max_id).to_a.sample(amount)
    end

    def create_addy(file, user_info_id)
      addy = Vye::AddressChange.new(origin: 'frontend')
      addy.user_info_id = user_info_id
      addy.veteran_name = Faker::Name.name
      addy.address1 = Faker::Address.street_address[0, 20]
      addy.address2 = Faker::Address.secondary_address[0, 20] if user_info_id.modulo(3).eql?(0)
      addy.address3 = Faker::Address.building_number[0, 20] if user_info_id.modulo(15).eql?(0)
      addy.address4 = Faker::Address.community[0, 20] if user_info_id.modulo(45).eql?(0)
      addy.address5 = Faker::Address.mail_box[0, 20] if user_info_id.modulo(90).eql?(0)
      addy.city = Faker::Address.city[0, 20]
      addy.state = Faker::Address.state_abbr
      addy.zip_code = Faker::Address.zip

      if addy.valid?
        if addy.save
          file.puts "Created addy change for user #{user_info_id}"
          file.puts "  Name:  #{addy.veteran_name}"
          file.puts "  Addy1: #{addy.address1}"
          file.puts "  Addy2: #{addy.address2}"
          file.puts "  Addy3: #{addy.address3}" if addy.address3
          file.puts "  Addy4: #{addy.address4}" if addy.address4
          file.puts "  Addy5: #{addy.address5}" if addy.address5
          file.puts "  c/s/z: #{addy.city}, #{addy.state}, #{addy.zip_code}\n\n"
        else
          file.puts "Failed to save addy change for user #{user_info_id}"
        end
      else
        file.puts "Invalid addy change for user #{user_info_id}"
      end
    end

    def create_direct_deposit_changes(file, user_info_id)
      ddc = Vye::DirectDepositChange.new
      ddc.user_info_id = user_info_id
      ddc.full_name = Faker::Name.name
      ddc.phone = Faker::Number.number(digits: 10)
      ddc.email = Faker::Internet.email
      ddc.acct_no = Faker::Bank.account_number(digits: 10)
      ddc.acct_type = Vye::DirectDepositChange.acct_types.keys.sample
      ddc.routing_no = Faker::Bank.routing_number
      ddc.bank_name = Faker::Bank.name
      ddc.bank_phone = Faker::Number.number(digits: 10)
      ddc.save

      file.puts "Created direct deposit change for user #{user_info_id}"
      file.puts "  Name: #{ddc.full_name}"
      file.puts "  Phone/Email: #{ddc.phone}, #{ddc.email}"
      file.puts "  Acct no/type: #{ddc.acct_no}, #{ddc.acct_type}"
      file.puts "  Bank routing no/name/phone: #{ddc.routing_no}, #{ddc.bank_name}, #{ddc.bank_phone}\n\n"
    end

    def create_verification_changes(file, user_info_id)
      vc = Vye::Verification.new(source_ind: 'web')
      vc.user_info_id = user_info_id
      vc.user_profile_id = Vye::UserInfo.find(user_info_id).user_profile_id
      vc.award_id = Vye::UserInfo.find(user_info_id).awards&.first&.id
      vc.transact_date = Time.zone.now

      if vc.valid?
        if vc.save
          file.puts "Created verification change for user #{user_info_id}"
          file.puts "  Award: #{vc.award_id}"
          file.puts "  Source: #{vc.source_ind}"
          file.puts "  Transact Date: #{vc.transact_date}\n\n"
        else
          file.puts "Failed to save verification change for user #{user_info_id}"
        end
      else
        file.puts "Invalid verification change for user #{user_info_id}"
      end
    end
  end
end
