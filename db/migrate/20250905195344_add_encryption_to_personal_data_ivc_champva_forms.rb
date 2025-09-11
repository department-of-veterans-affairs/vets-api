class AddEncryptionToPersonalDataIvcChampvaForms < ActiveRecord::Migration[7.2]
    disable_ddl_transaction!
  
    def change
      add_column :ivc_champva_forms, :first_name_ciphertext, :text
      add_column :ivc_champva_forms, :last_name_ciphertext, :text
      add_column :ivc_champva_forms, :email_ciphertext, :text
  
      # Add blind index for searchable encrypted email field
      add_column :ivc_champva_forms, :email_bidx, :string
      add_index :ivc_champva_forms, :email_bidx, algorithm: :concurrently
    end
  end
  