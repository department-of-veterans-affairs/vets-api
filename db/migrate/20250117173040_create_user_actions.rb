class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    # Create the enum type first
    create_enum :user_action_status, ['initial', 'success', 'error']

    create_table :user_actions, id: :uuid do |t|
      # Core fields
      t.references :acting_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :subject_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :user_action_event, null: false, foreign_key: true
      t.enum :status, enum_type: :user_action_status, default: 'initial', null: false, index: true

      # Additional columns from ticket
      t.boolean :user_verified, default: false, null: false
      t.text :ip_address
      t.text :device_info

      t.timestamps null: false
    end
  end
end
