class CreateForm1095Bs < ActiveRecord::Migration[6.1]
  def change
    create_table :form1095_bs, id: :uuid do |t|
      t.string :veteran_icn, null: false
      t.integer :tax_year, null: false
      t.jsonb :form_data_ciphertext, null: false
      t.text :encrypted_kms_key

      t.timestamps
    end
    
    add_index :form1095_bs, [:veteran_icn, :tax_year], unique: true
  end
end
