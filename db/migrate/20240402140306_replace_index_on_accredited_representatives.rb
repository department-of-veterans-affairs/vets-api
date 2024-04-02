# frozen_string_literal: true

class ReplaceIndexOnAccreditedRepresentatives < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :accredited_representatives, column: %i[number first_name last_name], name: 'index_rep_group'
    add_index :accredited_representatives, :number, unique: true, algorithm: :concurrently
  end
end
