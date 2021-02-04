# frozen_string_literal: true

namespace :test_user_account do
  desc 'Load the test user accounts from CSV'
  task load: :environment do
    file_path = Rails.root.join('modules', 'test_user_dashboard', 'db', 'seeds', 'test_users.csv')
    CSV.foreach(file_path, headers: true) do |row|
      ::TestUserDashboard::CreateTestUserAccount.new(row).call
    end
  end
end
