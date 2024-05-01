# frozen_string_literal: true

namespace :db do
  desc 'Check database connectivity and perform test operations'
  task check: :environment do
    # Test 1: Check Connection
    if ActiveRecord::Base.connection.active?
      puts 'Connection is active.'
    else
      puts 'Connection is not active.'
      return # Exit the task if connection fails
    end

    # Test 2: Access Records
    begin
      if UserAccount.exists?
        puts 'UserAccount records exist.'
      else
        puts 'No UserAccount records found but database is up.'
      end
    rescue => e
      puts "Failed to check UserAccount records due to error: #{e.message}"
      return # Exit the task if connectivity issues are detected
    end

    # Test 3: Perform GET and PUT operations
    begin
      UserAccount.transaction do
        icn = 'abc123'
        UserAccount.create!(icn:)
        puts "Created UserAccount with ICN: #{icn}"

        user = UserAccount.find_by(icn:)
        puts 'Updated UserAccount ICN' if user.update(icn: 'xyz789')

        # Roll back transaction so the changes aren't persisted.
        raise ActiveRecord::Rollback
      end
      puts 'Transaction rolled back successfully.'
    rescue => e
      puts "Error during GET and PUT operations: #{e.message}"
    end
  end
end
