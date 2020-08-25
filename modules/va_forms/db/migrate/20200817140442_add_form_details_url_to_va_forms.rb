# frozen_string_literal: true

class AddFormDetailsUrlToVaForms < ActiveRecord::Migration[6.0]
  def change
    add_column :va_forms_forms, :form_details_url, :string
  end
end
