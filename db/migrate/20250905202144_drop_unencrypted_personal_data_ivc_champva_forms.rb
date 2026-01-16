class DropUnencryptedPersonalDataIvcChampvaForms < ActiveRecord::Migration[7.2]
    def change
      safety_assured { remove_column :ivc_champva_forms, :first_name, :string }
      safety_assured { remove_column :ivc_champva_forms, :last_name, :string }
      safety_assured { remove_column :ivc_champva_forms, :email, :string }
    end
  end
