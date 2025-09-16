# frozen_string_literal: true

class AddIndexToAccounts < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :accounts, :icn, algorithm: :concurrently
  end
end
