# frozen_string_literal: true

class CreateTestUserAccount
  attr_accessor :row, :test_user_account

  def initialize(row={})
    @test_user_account = ::TestUserDashboard::TudAccount.new(row)

  end

  def call
    test_user_account.save!
    # MPI fetch or create if not found

    test_user_account
  end
end
