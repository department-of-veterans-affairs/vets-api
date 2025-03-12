# frozen_string_literal: true

class CreateUserActions < ActiveRecord::Migration[7.2]
  def change
    create_enum :user_action_status, %w[initial success error]
    create_table :user_actions, id: :uuid do |t|
      t.references :acting_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :subject_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.references :user_action_event, null: false, foreign_key: true
      t.enum :status, enum_type: :user_action_status, default: 'initial', null: false, index: true
      # Tracks the CSP (idme, logingov, mhv, dslogon) and verification status at time of action
      t.references :subject_user_verification, foreign_key: { to_table: :user_verifications }
      t.text :acting_ip_address
      t.text :acting_user_agent
      t.timestamps null: false
    end
  end
end
