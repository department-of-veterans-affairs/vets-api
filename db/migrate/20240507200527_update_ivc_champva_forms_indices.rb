# frozen_string_literal: true

class UpdateIvcChampvaFormsIndices < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :ivc_champva_forms, :form_uuid, algorithm: :concurrently
    remove_index :ivc_champva_forms, name: 'index_ivc_champva_forms_on_email'
  end
end
