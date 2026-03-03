# frozen_string_literal: true

class AddRequestJsonToIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:ivc_champva_forms, :request_json_ciphertext)
      add_column :ivc_champva_forms, :request_json_ciphertext, :text
    end
  end
end
