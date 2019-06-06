# frozen_string_literal: true

class AddPoaCodesToVeteranRepresentatives < ActiveRecord::Migration[5.2]
  def change
    add_column :veteran_representatives, :poa_codes, :string, array: true
  end
end
