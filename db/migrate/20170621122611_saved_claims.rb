class SavedClaims < ActiveRecord::Migration[4.2]
  def change
    create_table(:saved_claims) do |t|
      t.timestamps
      t.string :encrypted_form, null: false
      t.string :encrypted_form_iv, null: false
      t.string :form_type
      t.uuid :guid, null: false
    end
  end
end
