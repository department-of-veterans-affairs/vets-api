# frozen_string_literal: true

# Test migration that violates Copilot instructions
# This intentionally breaks the index migration rules

class TestBadMigration < ActiveRecord::Migration[7.0]
  def change
    # Violation 1: Mixing index changes with other schema updates
    add_column :users, :test_field, :string

    # Violation 2: Adding index without algorithm: :concurrently
    # Violation 3: No disable_ddl_transaction!
    add_index :users, :test_field

    # Violation 4: Another schema change mixed with index
    add_column :users, :another_field, :integer
    add_index :users, :another_field
  end
end
