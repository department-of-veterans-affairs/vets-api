# frozen_string_literal: true

class AddVsrType < ActiveRecord::Migration[5.2]
  def change
    add_column :veteran_representatives, :user_types, :string, array: true
  end
end
  