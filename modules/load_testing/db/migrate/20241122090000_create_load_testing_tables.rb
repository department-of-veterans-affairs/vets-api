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

    # Create the load test client config
    reversible do |dir|
      dir.up do
        # Skip in test environment
        next if Rails.env.test?

        SignIn::ClientConfig.find_or_create_by!(client_id: 'load_test_client') do |config|
          config.redirect_uri = 'http://localhost:3000/load_testing/callback'
          config.scopes = ['openid', 'profile', 'email']
          config.auth_type = 'logingov'
          config.cookie_auth = false
          config.terms_of_use_url = nil
          config.description = 'Load Testing Client'
        end
      end

      dir.down do
        # Skip in test environment
        next if Rails.env.test?

        SignIn::ClientConfig.find_by(client_id: 'load_test_client')&.destroy
      end
    end
  end
end 