# frozen_string_literal: true

class RemovePoaFromVeteranRepresentatives < ActiveRecord::Migration[5.2]
  def change
    remove_column :veteran_representatives, :poa, :string
  end
end
