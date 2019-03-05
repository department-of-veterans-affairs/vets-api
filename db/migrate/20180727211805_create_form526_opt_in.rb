class CreateForm526OptIn < ActiveRecord::Migration[4.2]
  def change
    create_table :form526_opt_ins do |t|
      t.string :user_uuid, null: false
      t.string :encrypted_email, null: false
      t.string :encrypted_email_iv, null: false
      t.timestamps null: false
    end
  end
end
