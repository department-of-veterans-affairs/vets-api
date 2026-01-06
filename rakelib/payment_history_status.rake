# frozen_string_literal: true

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
end
