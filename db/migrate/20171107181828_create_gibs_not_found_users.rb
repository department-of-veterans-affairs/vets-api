class CreateGibsNotFoundUsers < ActiveRecord::Migration
  def change
    create_table :gibs_not_found_users do |t|
      t.string :edipi, null: false, unique: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :encrypted_ssn, null: false
      t.string :encrypted_ssn_iv, null: false
      t.datetime :dob, null: false
      t.timestamps null: false
    end
  end
end
