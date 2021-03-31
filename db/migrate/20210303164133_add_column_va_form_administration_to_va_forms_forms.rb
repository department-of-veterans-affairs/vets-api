class AddColumnVAFormAdministrationToVAFormsForms < ActiveRecord::Migration[6.0]
  def change
    add_column :va_forms_forms, :va_form_administration, :jsonb
  end
end
