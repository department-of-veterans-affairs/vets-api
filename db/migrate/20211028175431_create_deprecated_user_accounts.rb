class CreateDeprecatedUserAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :deprecated_user_accounts do |t|
      t.references :user_accounts, type: :uuid, foreign_key: :true, null: :false, index: { unique: true }
      t.references :user_verifications, foreign_key: :true, null: :false, index: { unique: true }
      t.timestamps
    end
  end
end
