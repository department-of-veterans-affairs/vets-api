# frozen_string_literal: true

class CreateVaForms < ActiveRecord::Migration[5.2]
  def change
    create_table :va_forms_forms do |t|
      t.string :form_name
      t.string :url
      t.string :title
      t.date :first_issued_on
      t.date :last_revision_on
      t.integer :pages
      t.string :sha256
      t.timestamps null: false
    end
  end
end
