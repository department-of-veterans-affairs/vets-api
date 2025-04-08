class AddEncryptionToVesDataIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    add_column :ivc_champva_forms, :ves_request_data_ciphertext, :text unless column_exists?(:ivc_champva_forms, :ves_request_data_ciphertext)
    add_column :ivc_champva_forms, :encrypted_kms_key, :text unless column_exists?(:ivc_champva_forms, :encrypted_kms_key)
  end
end