# frozen_string_literal: true

namespace :test_user_account do
  desc 'Load the test user accounts from CSV'
  task :load, [:path] => [:environment] do |_t, args|
    CSV.foreach(args[:path], headers: true) do |row|
      TestUserDashboard::CreateTestUserAccount.new(row).call
    end
  end
end
