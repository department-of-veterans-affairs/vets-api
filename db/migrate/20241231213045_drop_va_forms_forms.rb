class DropVAFormsForms < ActiveRecord::Migration[7.2]
  def change
    drop_table :va_forms_forms, if_exists: true
  end
end
