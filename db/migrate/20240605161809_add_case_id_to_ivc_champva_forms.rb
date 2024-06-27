class AddCaseIdToIvcChampvaForms < ActiveRecord::Migration[7.1]
  def change
    add_column :ivc_champva_forms, :case_id, :string, null: true
  end
end
