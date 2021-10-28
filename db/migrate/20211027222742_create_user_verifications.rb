class CreateUserVerifications < ActiveRecord::Migration[6.1]
  def change
    create_table :user_verifications do |t|
      t.references :user_accounts, type: :uuid, foreign_key: :true, null: :false, index: { unique: true }
      t.string :idme_uuid, index: { unique: true }
      t.string :logingov_uuid, index: { unique: true }
      t.string :mhv_uuid, index: { unique: true }
      t.string :dslogon_uuid, index: { unique: true }
      t.datetime :verified_at, index: true
      t.timestamps
    end
  end
end
