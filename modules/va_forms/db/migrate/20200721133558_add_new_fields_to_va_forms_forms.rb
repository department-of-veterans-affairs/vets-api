# frozen_string_literal: true

class AddNewFieldsToVaFormsForms < ActiveRecord::Migration[6.0]
  def change
    add_column :va_forms_forms, :form_usage, :text
    add_column :va_forms_forms, :form_tool_intro, :text
    add_column :va_forms_forms, :form_tool_url, :string
    add_column :va_forms_forms, :form_type, :string
    add_column :va_forms_forms, :language, :string
    add_column :va_forms_forms, :deleted_at, :datetime
    add_column :va_forms_forms, :related_forms, :string, array: true
    add_column :va_forms_forms, :benefit_categories, :jsonb
  end
end
