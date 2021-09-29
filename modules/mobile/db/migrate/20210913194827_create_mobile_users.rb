class CreateMobileUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :mobile_users do |t|
      t.string :icn, null: false
      t.timestamps null: false
      t.index [:icn], unique: true
    end
  end
end
