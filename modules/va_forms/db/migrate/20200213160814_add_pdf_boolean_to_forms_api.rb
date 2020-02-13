class AddPdfBooleanToFormsApi < ActiveRecord::Migration[5.2]  
  safety_assured
  
  def change
    add_column :va_forms_forms, :valid_pdf, :boolean, null: false
    add_index :va_forms_forms, :valid_pdf
  end
end
