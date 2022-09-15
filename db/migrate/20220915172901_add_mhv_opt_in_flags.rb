class AddMHVOptInFlags < ActiveRecord::Migration[6.1]
  def change
    create_table :mhv_opt_in_flags do |t|
      t.string :user_account_uuid, null: false
      t.string :opt_in_flag, null: false

      t.index [ "user_account_uuid" ],  unique: false
      t.index [ "opt_in_flag" ],  unique: false
      t.timestamps
    end
  end
end
