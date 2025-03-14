class CreateArIcnTemporaryIdentifiers < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_icn_temporary_identifiers, id: :uuid do |t|
      t.string :icn_ciphertext, null: false
      t.text :encrypted_kms_key
      t.datetime :created_at
    end
  end
end
