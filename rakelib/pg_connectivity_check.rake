# frozen_string_literal: true

namespace :db do
  desc 'Check database connectivity and perform test operations'
  task check: :environment do
    puts '*** Test 1: Access Records'
    begin
      if UserAccount.exists?
        puts 'UserAccount records exist.'
      else
        puts 'No UserAccount records found but database is up.'
      end
    rescue => e
      Rails.logger.error(
        { message: "Failed to access UserAccount records during Postgres connectivity check. Error: #{e.message}" }
      )
      return # Exit the task if connectivity issues are detected
    end

    puts '*** Test 2: Perform GET and PUT operations'
    begin
      UserAccount.transaction do
        icn = 'abc123'
        UserAccount.create!(icn:)
        puts 'Created UserAccount'

        user = UserAccount.find_by(icn:)
        puts 'Updated UserAccount ICN' if user.update(icn: 'xyz789')

        # Roll back transaction so the changes aren't persisted.
        raise ActiveRecord::Rollback
      end
      puts 'Transaction rolled back successfully.'
    rescue => e
      Rails.logger.error(
        { message: "Error during GET and PUT operations for Postgres connectivity check. Error: #{e.message}" }
      )
      return # Exit the task if connectivity issues are detected
    end

    puts '*** Test 3: Check Connection'
    # Order matters. This command returns false if it's run before the other tests
    if ActiveRecord::Base.connection.active?
      puts 'Connection is active.'
    else
      Rails.logger.error({ message: 'Postgres Connection is NOT active.' })
      return # Exit the task if connection fails
    end
  end
end
