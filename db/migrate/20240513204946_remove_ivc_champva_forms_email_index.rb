class RemoveIvcChampvaFormsEmailIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :ivc_champva_forms, name: 'index_ivc_champva_forms_on_email', if_exists: true
  end
end
