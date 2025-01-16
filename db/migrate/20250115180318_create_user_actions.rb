class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    create_table :user_actions, id: :uuid do |t|
      # Core fields
      t.references :user_account, type: :uuid, null: false, foreign_key: true
      t.uuid :acting_user_account_id, null: false
      t.uuid :subject_user_account_id, null: false
      t.references :user_action_event, null: false, foreign_key: true
      t.string :status, default: 'initial' # initial, success, error

      # Additional columns from ticket
      t.boolean :user_verified, default: false
      t.string :ip_address
      t.jsonb :device_info

      t.timestamps null: false

      # Add index for status queries
      t.index :status
    end

    # Add check constraint for status values
    reversible do |dir|
      dir.up do
        safety_assured do
          execute <<-SQL
            ALTER TABLE user_actions
              ADD CONSTRAINT check_status
              CHECK (status IN ('initial', 'success', 'error'));
          SQL
        end
      end
    end

    # Add foreign key for acting_user_account_id
    add_foreign_key :user_actions, :user_accounts, column: :acting_user_account_id
    # Add foreign key for subject_user_account_id
    add_foreign_key :user_actions, :user_accounts, column: :subject_user_account_id
  end
end 