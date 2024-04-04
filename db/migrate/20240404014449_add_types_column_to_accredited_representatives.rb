# frozen_string_literal: true

class AddTypesColumnToAccreditedRepresentatives < ActiveRecord::Migration[7.1]
  def change
    add_column :accredited_representatives, :types, :string, array: true
  end
end
