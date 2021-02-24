# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :test_user_account

    def initialize(row = {})
      account_hash       = row.to_hash
      @test_user_account = TudAccount.new(account_hash)
    end

    def call
      test_user_account.mpi_uuid = test_user_account.user.account.uuid
      test_user_account.services = test_user_account.profile.services
      test_user_account.save!
      test_user_account
    end
  end
end
