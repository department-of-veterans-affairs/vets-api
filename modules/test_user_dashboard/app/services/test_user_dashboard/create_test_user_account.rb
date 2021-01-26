# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :row, :test_user_account

    def initialize(row = {})
      account_hash = row.to_hash
      @test_user_account = TudAccount.new(account_hash)
    end

    def call
      test_user_account.save!
      # MPI fetch or create if not found
      test_user_account
    end
  end
end
