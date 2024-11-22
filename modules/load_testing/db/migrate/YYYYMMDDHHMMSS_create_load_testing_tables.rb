class CreateLoadTestingTables < ActiveRecord::Migration[7.1]
  def change
    create_table :load_testing_test_sessions do |t|
      t.string :status, null: false
      t.integer :concurrent_users, null: false
      t.jsonb :configuration
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :load_testing_test_tokens do |t|
      t.references :test_session, null: false, foreign_key: { to_table: :load_testing_test_sessions }
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.string :device_secret
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :load_testing_test_sessions, :status
    add_index :load_testing_test_tokens, :expires_at
  end
end 