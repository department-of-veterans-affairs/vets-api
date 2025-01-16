class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    create_table :user_actions do |t|
      # From diagram
      t.string :uuid, null: false, index: { unique: true }
      t.uuid :acting_user_account_id, null: false
      t.uuid :subject_user_account_id, null: false
      t.bigint :user_action_event_id
      t.string :status, default: 'initial' # initial, success, error

      # Additional columns from ticket
      t.boolean :user_verified, default: false
      t.string :ip_address
      t.jsonb :device_info

      t.timestamps null: false
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
  end
end 