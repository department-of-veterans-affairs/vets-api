class AddColumnRowIdToVAFormsForms < ActiveRecord::Migration[6.0]
  def change
    add_column :va_forms_forms, :row_id, :integer
  end
end
