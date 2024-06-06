class AddCaseIdToIvcChampvaForms < ActiveRecord::Migration[7.1]
  def change
    add_column :ivc_champva_forms, :pega_case_id, :string, null: true
  end
end
