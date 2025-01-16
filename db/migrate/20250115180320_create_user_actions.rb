class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    # Create the enum type first
    create_enum :user_action_status, ['initial', 'success', 'error']

    create_table :user_actions, id: :uuid do |t|
      # Core fields
      t.uuid :acting_user_account_id, null: false
      t.uuid :subject_user_account_id, null: false
      t.references :user_action_event, null: false, foreign_key: { validate: false }
      t.enum :status, enum_type: :user_action_status, default: 'initial', null: false

      # Additional columns from ticket
      t.boolean :user_verified, default: false
      t.string :ip_address
      t.jsonb :device_info

      t.timestamps null: false

      # Add index for status queries
      t.index :status
    end

    # Add foreign keys without validation
    add_foreign_key :user_actions, :user_accounts, column: :acting_user_account_id, validate: false
    add_foreign_key :user_actions, :user_accounts, column: :subject_user_account_id, validate: false
  end
end 