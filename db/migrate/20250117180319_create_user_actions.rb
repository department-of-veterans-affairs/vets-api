# frozen_string_literal: true

class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    # Create the enum type first
    create_enum :user_action_status, %w[initial success error]

    create_table :user_actions, id: :uuid do |t|
      # Core fields
      t.references :acting_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :subject_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :user_action_event, null: false, foreign_key: true
      t.enum :status, enum_type: :user_action_status, default: 'initial', null: false, index: true

      # Note: SubjectUserVerification will be added in a future enhancement
      # when the UserVerification table is implemented. This will provide
      # information about the CSP used and verification status.
      t.string :acting_user_ip_address
      t.string :acting_user_device

      t.timestamps null: false
    end
  end
end
