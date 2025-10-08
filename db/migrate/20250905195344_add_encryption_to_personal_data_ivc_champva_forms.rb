class AddEncryptionToPersonalDataIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    add_column :ivc_champva_forms, :first_name_ciphertext, :text, if_not_exists: true
    add_column :ivc_champva_forms, :last_name_ciphertext, :text, if_not_exists: true
    add_column :ivc_champva_forms, :email_ciphertext, :text, if_not_exists: true
    
    # Add blind index for searchable encrypted email field
    add_column :ivc_champva_forms, :email_bidx, :string, if_not_exists: true
  end
end
  