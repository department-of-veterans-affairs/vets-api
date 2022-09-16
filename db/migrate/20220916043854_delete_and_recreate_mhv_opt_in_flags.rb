class DeleteAndRecreateMHVOptInFlags < ActiveRecord::Migration[6.1]
  def up
    drop_mhv_opt_in_flags_table
    create_mhv_opt_in_flags_table
  end

  def down
    drop_mhv_opt_in_flags_table
    create_table :mhv_opt_in_flags do |t|
      t.string :user_account_uuid, null: false
      t.string :opt_in_flag, null: false

      t.index [ "user_account_uuid" ],  unique: false
      t.index [ "opt_in_flag" ],  unique: false
      t.timestamps
    end
  end

  private

  def drop_mhv_opt_in_flags_table
    drop_table :mhv_opt_in_flags
  end

  def create_mhv_opt_in_flags_table
    create_table :mhv_opt_in_flags do |t|
      t.references :user_account, type: :uuid, foreign_key: :true, null: :false, index: true
      t.string :feature, null: false
      t.index [ "feature" ],  unique: false
      t.timestamps
    end
  end
end
