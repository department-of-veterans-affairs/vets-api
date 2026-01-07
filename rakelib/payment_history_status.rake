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
    check_user_exists(icn)
    
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
    rescue => e
      puts "✗ Error querying MPI: #{e.message}"
    end
  end
end
