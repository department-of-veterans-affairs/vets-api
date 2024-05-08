# frozen_string_literal: true

module DatabaseHealthChecker
  def self.postgres_up
    user_account_exists && get_and_put_operations && active_db_connection
  end

  def self.user_account_exists
    # Test 1: Access Records
    UserAccount.exists?
    true # Return true if no exception occurs
  rescue => e
    Rails.logger.info(
      { message: "ARGO CD UPGRADE - PG TEST: Failed to access UserAccount. Error: #{e.message}" }
    )
    false
  end

  def self.get_and_put_operations
    # Test 2: Perform GET and PUT operations and roll back transaction
    # so the changes aren't persisted.
    UserAccount.transaction do
      icn = 'abc123'
      UserAccount.create!(icn:)

      user = UserAccount.find_by(icn:)
      unless user
        Rails.logger.info({ message: "ARGO CD UPGRADE - PG TEST: No UserAccount found with ICN #{icn}" })
        raise ActiveRecord::Rollback
      end
      user.update(icn: 'xyz789')

      raise ActiveRecord::Rollback
    end
    true
  rescue => e
    Rails.logger.info(
      { message: "ARGO CD UPGRADE - PG TEST: Error in GET/PUT operations. Error: #{e.message}" }
    )
    false # Return false if connectivity issues are detected
  end

  def self.active_db_connection
    # Test 3: Check Connection
    if ActiveRecord::Base.connection.active?
      true
    else
      Rails.logger.info({ message: 'ARGO CD UPGRADE - PG TEST: Connection is NOT active.' })
      false # Return false if the connection is not active
    end
  end
end
