class UpdateAssociationsUserVerificationsDeprecatedUserAccounts < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    drop_user_tables
    create_user_tables
  end

  def down
    drop_user_tables
    create_user_tables
  end

  private

  def drop_user_tables
    drop_table :deprecated_user_accounts
    drop_table :user_verifications
    drop_table :user_accounts
  end

  def create_user_tables
    create_table :user_accounts, id: :uuid do |t|
      t.string :icn
      t.timestamps
      t.index :icn, name: "index_user_accounts_on_icn", unique: true
    end

    create_table :user_verifications do |t|
      t.references :user_account, type: :uuid, foreign_key: :true, null: :false, index: { unique: true }
      t.string :idme_uuid, index: { unique: true }
      t.string :logingov_uuid, index: { unique: true }
      t.string :mhv_uuid, index: { unique: true }
      t.string :dslogon_uuid, index: { unique: true }
      t.datetime :verified_at, index: true
      t.timestamps
    end

    create_table :deprecated_user_accounts do |t|
      t.references :user_account, type: :uuid, foreign_key: :true, null: :false, index: { unique: true }
      t.references :user_verification, foreign_key: :true, null: :false, index: { unique: true }
      t.timestamps
    end
  end
end
