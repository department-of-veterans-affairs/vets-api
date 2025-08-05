class RemoveVesDataFromIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :ivc_champva_forms, :ves_data }
  end
end
