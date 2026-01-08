# frozen_string_literal: true

# This rake file is a diagnostic tool to investigate why a user might be getting
# an empty payment history response from the payment history controller.
# It checks various conditions that could cause payment history to be empty.

namespace :payment_history do
  desc 'Debug why payment history is empty for given ICNs'
  task :debug_empty, [:icn] => :environment do |_t, args|
    icn = args[:icn]
    
    if icn.blank?
      puts 'Usage: rake payment_history:debug_empty[ICN]'
      puts 'Example: rake payment_history:debug_empty[1234567890V123456]'
      exit 1
    end

    puts "Checking payment history status..."
    puts "ICN: #{mask_icn(icn)}"
    puts '-' * 40
    
    check_feature_flag
    mpi_profile = check_user_exists(icn)

    is_passing_policy = nil

    if mpi_profile != nil
      is_passing_policy = check_policy_attributes(mpi_profile)
    end
    
    puts
  end

  def mask_icn(icn)
    return 'nil' if icn.nil?
    return icn if icn.length < 4
    
    "#{icn[0..3]}#{'*' * (icn.length - 4)}"
  end

  def check_feature_flag
    enabled = Flipper.enabled?(:payment_history)
    
    if enabled
      puts "✓ Feature Flag: payment_history is ENABLED"
    else
      puts "✗ Feature Flag: payment_history is DISABLED"
      puts "  This will cause payment history to return nil"
      puts "  Enable with: Flipper.enable(:payment_history)"
    end
  end

  def check_user_exists(icn)
    puts
    puts "Checking if user can be found..."
    mpi_profile = nil
    
    # Try to find UserAccount by ICN
    user_account = UserAccount.find_by(icn: icn)
    
    if user_account
      puts "✓ UserAccount found: ID #{user_account.id}"
      puts "  Created: #{user_account.created_at}"
      puts "  Verified: #{user_account.verified?}"
    else
      puts "✗ UserAccount not found in database"
      puts "  User may not have logged in or ICN may be incorrect"
    end
    
    # Try to find user in MPI
    begin
      mpi_service = MPI::Service.new
      response = mpi_service.find_profile_by_identifier(
        identifier: icn,
        identifier_type: MPI::Constants::ICN
      )
      
      if response.ok?
        puts "✓ User found in MPI"
        puts "  Name: #{response.profile.given_names&.first} #{response.profile.family_name}"
        puts "  ICN: #{mask_icn(response.profile.icn)}"
      elsif response.not_found?
        puts "✗ User not found in MPI"
        puts "  ICN may be invalid or user may not exist in Master Person Index"
      else
        puts "✗ MPI lookup failed: #{response.error&.message}"
      end

      mpi_profile = response.profile
    rescue => e
      puts "✗ Error querying MPI: #{e.message}"
    end

    mpi_profile
  end

  def check_policy_attributes(mpi_profile)
    puts
    puts "Checking BGS policy access requirements..."
    
    has_icn = mpi_profile.icn.present?
    has_ssn = mpi_profile.ssn.present?
    has_participant_id = mpi_profile.participant_id.present?
    
    if has_icn
      puts "✓ ICN present: #{mask_icn(mpi_profile.icn)}"
    else
      puts "✗ ICN missing"
      puts "  BGS policy requires ICN to be present"
    end
    
    if has_ssn
      puts "✓ SSN present: ***-**-#{mpi_profile.ssn.to_s[-4..]}"
    else
      puts "✗ SSN missing"
      puts "  BGS policy requires SSN to be present"
    end
    
    if has_participant_id
      puts "✓ Participant ID present: #{mpi_profile.participant_id}"
    else
      puts "✗ Participant ID missing"
      puts "  BGS policy requires Participant ID to be present"
    end
    
    all_present = has_icn && has_ssn && has_participant_id
    
    puts
    if all_present
      puts "✓ User has all required attributes for BGS policy access"
    else
      puts "✗ User is missing required attributes for BGS policy access"
      puts "  Payment history will be denied due to missing attributes"
    end
    
    all_present
  end
end
