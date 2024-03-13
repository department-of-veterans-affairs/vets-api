class AddChangeHistoryToVAFormsForms < ActiveRecord::Migration[7.0]
  def change
    add_column :va_forms_forms, :change_history, :jsonb
  end
end
