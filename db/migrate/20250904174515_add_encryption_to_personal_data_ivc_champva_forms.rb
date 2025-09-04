class AddEncryptionToPersonalDataIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    add_column :ivc_champva_forms, :first_name_ciphertext, :text
    add_column :ivc_champva_forms, :last_name_ciphertext, :text
    add_column :ivc_champva_forms, :email_ciphertext, :text
  end
end
