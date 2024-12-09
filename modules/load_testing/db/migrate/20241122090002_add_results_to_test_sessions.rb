class AddResultsToTestSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :load_testing_test_sessions, :results, :jsonb
  end
end 