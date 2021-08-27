class CreateAccountLoginStats < ActiveRecord::Migration[6.1]
  def change
    create_table :account_login_stats do |t|
      t.references :account, foreign_key: true, null: false, index: { unique: true }
      t.datetime :idme_at, index: true
      t.datetime :myhealthevet_at, index: true
      t.datetime :dslogon_at, index: true
      t.timestamps
    end
  end
end
