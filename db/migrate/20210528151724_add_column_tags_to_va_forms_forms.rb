class AddColumnTagsToVAFormsForms < ActiveRecord::Migration[6.0]
  def change
    add_column :va_forms_forms, :tags, :string
  end
end
