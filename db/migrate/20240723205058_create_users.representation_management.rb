class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :representation_management_users do |t|
      t.text :first_name_ciphertext
      t.text :last_name_ciphertext
      t.text :city_ciphertext
      t.text :state_ciphertext
      t.text :postal_code_ciphertext

      t.string :first_name_bidx
      t.string :last_name_bidx
      t.string :city_bidx
      t.string :state_bidx
      t.string :postal_code_bidx

      t.index :first_name_bidx, unique: true
      t.index :last_name_bidx, unique: true
      t.index :city_bidx, unique: true
      t.index :state_bidx, unique: true
      t.index :postal_code_bidx, unique: true

      t.text :encrypted_kms_key
      t.timestamps
    end
  end
end
